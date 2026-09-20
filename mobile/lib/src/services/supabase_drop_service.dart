import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_drop_service.dart';
import 'supabase_artist_tag_hydrator.dart';
import 'supabase_notification_service.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

class SupabaseDropService extends LocalDropService {
  SupabaseDropService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;
  List<KpopEntity>? _entityCatalogCache;
  DateTime? _entityCatalogCachedAt;

  @override
  bool get usesRealDrops => true;

  @override
  Future<void> recordView({
    required String dropId,
    required String playbackSessionId,
  }) async {
    if (dropId.isEmpty || playbackSessionId.isEmpty) return;
    await _client.rpc(
      'record_drop_view',
      params: {'p_drop_id': dropId, 'p_playback_session_id': playbackSessionId},
    );
  }

  @override
  Future<List<DropClip>> restoreDrops({
    int limit = 24,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    DropFeedMode feedMode = DropFeedMode.forYou,
  }) async {
    final stopwatch = Stopwatch()..start();
    final currentUserId = _client.auth.currentUser?.id;
    final effectiveAuthorId = onlyCurrentUser ? currentUserId : authorId;
    _logPerformance(
      'PERF_DROPS_FETCH_START limit=$limit offset=$offset authorId=${effectiveAuthorId ?? ''}',
    );
    final dropRows = await _restoreFeedRows(
      limit: limit,
      offset: offset,
      authorId: effectiveAuthorId,
      feedMode: feedMode,
    );
    if (dropRows.isEmpty) {
      _logPerformance(
        'PERF_DROPS_FETCH_OK count=0 elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return [];
    }
    final ids = dropRows.map((row) => row['id'] as String).toList();
    final likes = await _countsFor('drop_likes', 'drop_id', ids);
    final comments = await _commentCounts(ids);
    final userTags = await _userTagsFor(
      contentType: ProfileContentType.drop,
      ids: ids,
    );
    final storedArtistTags = await _artistTagsFor(
      contentType: ProfileContentType.drop,
      ids: ids,
    );
    final artistTags = await _resolveDropArtistTags(dropRows, storedArtistTags);
    final drops = dropRows
        .map(
          (row) => _dropFromRow(
            row,
            likes: likes[row['id']] ?? 0,
            comments: comments[row['id']] ?? 0,
            tags: userTags[row['id']] ?? const [],
            artistTags: artistTags[row['id']] ?? const [],
            isOwn: currentUserId != null && row['author_id'] == currentUserId,
          ),
        )
        .toList(growable: false);
    _logPerformance(
      'PERF_DROPS_FETCH_OK count=${drops.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return drops;
  }

  static const _dropSelect =
      'id,author_id,caption,artist_name,group_name,group_id,artist_id,'
      'audio,filter,location,video_url,storage_bucket,storage_path,'
      'duration_seconds,file_size,thumbnail_url,created_at,view_count,'
      'profiles:author_id(id,name,username,avatar_asset,avatar_url)';

  Future<List<Map<String, dynamic>>> _restoreFeedRows({
    required int limit,
    required int offset,
    required String? authorId,
    required DropFeedMode feedMode,
  }) async {
    if (authorId != null && authorId.isNotEmpty) {
      return _fetchDropRows(
        limit: limit,
        offset: offset,
        authorId: authorId,
      );
    }
    switch (feedMode) {
      case DropFeedMode.viral:
        return _fetchDropRows(
          limit: limit,
          offset: offset,
          orderByViews: true,
        );
      case DropFeedMode.following:
        final response = await _client.rpc(
          'hallyu_following_drops_v1',
          params: {'p_limit': limit, 'p_offset': offset},
        );
        return response is List
            ? response.cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[];
      case DropFeedMode.forYou:
        return _forYouRows(limit: limit);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDropRows({
    required int limit,
    required int offset,
    bool orderByViews = false,
    String? authorId,
    String? artistId,
    String? groupId,
  }) async {
    var query = _client
        .from('drops')
        .select(_dropSelect)
        .eq('status', 'published')
        .filter('deleted_at', 'is', null);
    if (authorId != null && authorId.isNotEmpty) {
      query = query.eq('author_id', authorId);
    }
    if (artistId != null && artistId.isNotEmpty) {
      query = query.eq('artist_id', artistId);
    }
    if (groupId != null && groupId.isNotEmpty) {
      query = query.eq('group_id', groupId);
    }
    final ordered = query
        .order(orderByViews ? 'view_count' : 'created_at', ascending: false)
        .order('created_at', ascending: false);
    final rows = await ordered.range(offset, offset + limit - 1);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<Set<String>> _followedProfileIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return <String>{};
    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['following_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _followedEntityIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return <String>{};
    final rows = await _client
        .from('kpop_entity_follows')
        .select('entity_id')
        .eq('user_id', userId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['entity_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _forYouRows({required int limit}) async {
    final followedProfiles = await _followedProfileIds();
    final followedEntities = await _followedEntityIds();
    final rows = <Map<String, dynamic>>[];
    for (final id in followedEntities) {
      rows.addAll(await _fetchDropRows(limit: limit, offset: 0, artistId: id));
      rows.addAll(await _fetchDropRows(limit: limit, offset: 0, groupId: id));
    }
    for (final id in followedProfiles) {
      rows.addAll(await _fetchDropRows(limit: limit, offset: 0, authorId: id));
    }
    rows.addAll(await _fetchDropRows(limit: limit, offset: 0));
    final candidates = _dedupeRows(rows);
    candidates.sort((a, b) {
      final score = _forYouScore(b, followedProfiles, followedEntities) -
          _forYouScore(a, followedProfiles, followedEntities);
      if (score != 0) return score;
      final date = _dateOf(b).compareTo(_dateOf(a));
      if (date != 0) return date;
      return ((b['view_count'] as num?)?.toInt() ?? 0).compareTo(
        (a['view_count'] as num?)?.toInt() ?? 0,
      );
    });
    return candidates.skip(0).take(limit).toList(growable: false);
  }

  static int _forYouScore(
    Map<String, dynamic> row,
    Set<String> followedProfiles,
    Set<String> followedEntities,
  ) {
    var score = 0;
    if (followedProfiles.contains(row['author_id']?.toString())) score += 100;
    if (followedEntities.contains(row['artist_id']?.toString()) ||
        followedEntities.contains(row['group_id']?.toString())) {
      score += 50;
    }
    return score;
  }

  static DateTime _dateOf(Map<String, dynamic> row) =>
      DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime(1970);

  static List<Map<String, dynamic>> _dedupeRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) byId.putIfAbsent(id, () => row);
    }
    return byId.values.toList(growable: true);
  }

  @override
  Future<DropClip> publish({
    required AuthUser author,
    required String videoPath,
    required String caption,
    required String artist,
    required String groupId,
    required String artistId,
    required String filter,
    Uint8List? videoBytes,
    String videoFileName = '',
    String videoMimeType = '',
    String location = '',
    String audio = 'Audio original',
    double? videoDurationSeconds,
    double videoTrimStartSeconds = 0,
    double? videoTrimEndSeconds,
    bool optimizedForUpload = false,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const DropServiceException(
        'Necesitás iniciar sesión para subir Drops.',
      );
    }
    if (videoPath.isEmpty) {
      throw const DropServiceException('Elegí o grabá un video primero.');
    }
    if (videoDurationSeconds != null &&
        videoDurationSeconds > LocalDropService.maxVideoDurationSeconds) {
      throw const DropServiceException(
        'El Drop supera 5 minutos. Recortalo antes de publicarlo.',
      );
    }

    _StoredDropVideo? stored;
    try {
      _log('DROP_STORAGE_UPLOAD_START', {
        'user': authUser.id,
        'bytes': videoBytes?.lengthInBytes,
        'fileName': videoFileName,
        'mimeType': videoMimeType,
      });
      stored = await _storeVideo(
        authUser.id,
        videoPath,
        videoBytes: videoBytes,
        fileName: videoFileName,
        mimeType: videoMimeType,
      );
      _log('DROP_STORAGE_UPLOAD_OK', {
        'bucket': stored.bucket,
        'path': stored.path,
        'contentType': stored.contentType,
        'bytes': stored.fileSize,
      });
    } on DropServiceException catch (error) {
      _log('DROP_UPLOAD_ERROR', {'step': 'storage', 'error': error.message});
      rethrow;
    } catch (error) {
      _log('DROP_UPLOAD_ERROR', {'step': 'storage', 'error': '$error'});
      throw const DropServiceException(
        'No pudimos subir el video. Revisá tu conexión y probá de nuevo.',
      );
    }

    final inserted = await _insertPublishedDrop(
      authorId: authUser.id,
      caption: caption,
      artist: artist,
      groupId: groupId,
      artistId: artistId,
      audio: audio,
      filter: filter,
      location: location,
      videoDurationSeconds: videoDurationSeconds,
      stored: stored,
    );
    final dropId = inserted['id'] as String;
    LocalDropService.revision.value++;
    return DropClip(
      id: dropId,
      title: caption.isEmpty ? 'Nuevo Drop' : caption,
      artist: artist.isEmpty ? 'Artista etiquetado' : artist,
      creator: author.username,
      creatorId: authUser.id,
      creatorName: author.name,
      creatorAvatarAsset: author.avatarAsset,
      audio: audio,
      imageAsset: 'assets/demo-posts/post-08.jpg',
      views: '0',
      viewCount: 0,
      likes: '0',
      comments: '0',
      groupId: groupId,
      artistId: artistId,
      caption: caption,
      location: location,
      videoPath: stored.publicUrl,
      videoDurationSeconds: videoDurationSeconds,
      videoTrimStartSeconds: videoTrimStartSeconds,
      videoTrimEndSeconds: videoTrimEndSeconds,
      optimizedForUpload: optimizedForUpload,
      filter: filter,
      taggedPeople: const [],
      taggedUserIds: const [],
      createdAt: DateTime.tryParse(inserted['created_at'] as String? ?? ''),
      isOwn: true,
    );
  }

  @override
  Future<void> deleteDrop(String id) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const DropServiceException('Necesitás iniciar sesión.');
    }
    try {
      await _client.rpc('delete_my_drop', params: {'p_drop_id': id});
    } catch (_) {
      await _client
          .from('drops')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('author_id', authUser.id);
    }
    LocalDropService.revision.value++;
  }

  @override
  Future<Set<String>> restoreLikedDropIds() async =>
      _idsForCurrentUser('drop_likes', 'drop_id');

  @override
  Future<Set<String>> restoreSavedDropIds() async =>
      _idsForCurrentUser('drop_saves', 'drop_id');

  @override
  Future<void> setDropLiked(String dropId, bool liked) async {
    await _setUserDropRelation(
      table: 'drop_likes',
      dropId: dropId,
      enabled: liked,
      actionLabel: 'dar estrella',
    );
  }

  @override
  Future<void> setDropSaved(String dropId, bool saved) async {
    await _setUserDropRelation(
      table: 'drop_saves',
      dropId: dropId,
      enabled: saved,
      actionLabel: 'guardar',
    );
  }

  @override
  Future<List<PostComment>> restoreComments(String dropId) async {
    final rows = await _client
        .from('drop_comments')
        .select(
          'id,parent_id,author_id,body,created_at,'
          'profiles:author_id(id,name,username,avatar_asset,avatar_url)',
        )
        .eq('drop_id', dropId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: true);
    return _commentsFromRows(rows.cast<Map<String, dynamic>>());
  }

  @override
  Future<PostComment> addComment({
    required AuthUser author,
    required String dropId,
    required String body,
    String parentId = '',
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const DropServiceException(
        'Necesitás iniciar sesión para comentar.',
      );
    }
    final cleaned = body.trim();
    if (cleaned.isEmpty) {
      throw const DropServiceException('Escribí un comentario primero.');
    }
    if (cleaned.length > LocalDropService.maxCommentLength) {
      throw const DropServiceException('El comentario es demasiado largo.');
    }
    final row = await _client
        .from('drop_comments')
        .insert({
          'drop_id': dropId,
          'parent_id': parentId.isEmpty ? null : parentId,
          'author_id': authUser.id,
          'body': cleaned,
        })
        .select(
          'id,parent_id,author_id,body,created_at,'
          'profiles:author_id(id,name,username,avatar_asset,avatar_url)',
        )
        .single();
    await _notifyDropOwner(
      dropId: dropId,
      actorId: authUser.id,
      type: 'drop_comment',
      title: 'Nuevo comentario en tu Drop',
      body: '${author.name} comentó tu Drop.',
      metadata: {
        'comment_id': row['id'] as String? ?? '',
        'preview': cleaned.length > 140 ? cleaned.substring(0, 140) : cleaned,
      },
      dedupe: true,
    );
    LocalDropService.revision.value++;
    return _commentFromRow(row, fallbackAuthor: author);
  }

  @override
  Future<void> deleteComment({
    required String dropId,
    required String commentId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const DropServiceException(
        'Necesitás iniciar sesión para borrar comentarios.',
      );
    }
    try {
      await _client.rpc(
        'delete_my_drop_comment',
        params: {'p_comment_id': commentId},
      );
    } catch (_) {
      await _client
          .from('drop_comments')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', commentId)
          .eq('drop_id', dropId)
          .eq('author_id', authUser.id);
    }
    LocalDropService.revision.value++;
  }

  Future<_StoredDropVideo> _storeVideo(
    String userId,
    String videoPath, {
    Uint8List? videoBytes,
    String fileName = '',
    String mimeType = '',
  }) async {
    final bytes = videoBytes ?? await _videoBytes(videoPath);
    if (bytes.isEmpty) {
      throw const DropServiceException(
        'El archivo parece estar vacío o no se pudo leer.',
      );
    }
    if (bytes.lengthInBytes > LocalDropService.maxVideoBytes) {
      throw const DropServiceException(
        'El video supera el límite de 100 MB del acceso anticipado.',
      );
    }
    final contentType = _videoContentType(
      videoPath,
      fileName: fileName,
      mimeType: mimeType,
    );
    final extension = _extensionForContentType(contentType);
    final path =
        '$userId/drop_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('drop_media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );
    return _StoredDropVideo(
      bucket: 'drop_media',
      path: path,
      publicUrl: _client.storage.from('drop_media').getPublicUrl(path),
      fileSize: bytes.lengthInBytes,
      contentType: contentType,
    );
  }

  Future<XFile> _videoFile(String videoPath) async {
    if (videoPath.startsWith('http://') ||
        videoPath.startsWith('https://') ||
        videoPath.startsWith('blob:') ||
        videoPath.startsWith('data:')) {
      throw const DropServiceException(
        'No pudimos preparar este video. Probá con otro clip más liviano.',
      );
    }
    return XFile(videoPath);
  }

  Future<Uint8List> _videoBytes(String videoPath) async {
    try {
      return (await (await _videoFile(videoPath)).readAsBytes());
    } catch (error) {
      if (error is DropServiceException) rethrow;
      throw const DropServiceException(
        'No pudimos leer el video seleccionado. Probá con otro archivo.',
      );
    }
  }

  String _videoContentType(
    String videoPath, {
    String fileName = '',
    String mimeType = '',
  }) {
    final normalizedMime = mimeType.toLowerCase();
    if (normalizedMime.startsWith('video/')) {
      if (normalizedMime.contains('quicktime')) return 'video/quicktime';
      if (normalizedMime.contains('webm')) return 'video/webm';
      if (normalizedMime.contains('mp4') || normalizedMime.contains('m4v')) {
        return 'video/mp4';
      }
    }
    final source = '$fileName $videoPath'.toLowerCase();
    if (source.contains('.mov')) return 'video/quicktime';
    if (source.contains('.webm')) return 'video/webm';
    if (source.contains('.mp4') || source.contains('.m4v')) return 'video/mp4';
    throw const DropServiceException(
      'Usá un video MP4, MOV o WebM durante el acceso anticipado.',
    );
  }

  String _extensionForContentType(String contentType) {
    return switch (contentType) {
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      _ => 'mp4',
    };
  }

  Future<Map<String, dynamic>> _insertPublishedDrop({
    required String authorId,
    required String caption,
    required String artist,
    required String groupId,
    required String artistId,
    required String audio,
    required String filter,
    required String location,
    required double? videoDurationSeconds,
    required _StoredDropVideo stored,
  }) async {
    _log('DROP_DB_INSERT_START', {
      'author': authorId,
      'bucket': stored.bucket,
      'path': stored.path,
      'status': 'published',
    });
    try {
      final row = await _client
          .from('drops')
          .insert({
            'author_id': authorId,
            'caption': caption,
            'artist_name': artist,
            'group_id': groupId,
            'artist_id': artistId,
            'audio': audio,
            'filter': filter,
            'location': location,
            'duration_seconds': videoDurationSeconds?.round(),
            'file_size': stored.fileSize,
            'storage_bucket': stored.bucket,
            'storage_path': stored.path,
            'video_url': stored.publicUrl,
            'status': 'published',
          })
          .select('id,created_at')
          .single();
      _log('DROP_DB_INSERT_OK', {'id': row['id']});
      return row;
    } catch (error) {
      _log('DROP_UPLOAD_ERROR', {'step': 'db_insert', 'error': '$error'});
      await _removeStoredVideo(stored);
      throw const DropServiceException(
        'El video se subió, pero no pudimos publicar el Drop. Probá de nuevo.',
      );
    }
  }

  Future<void> _removeStoredVideo(_StoredDropVideo stored) async {
    try {
      await _client.storage.from(stored.bucket).remove([stored.path]);
    } catch (_) {}
  }

  Future<Map<String, int>> _countsFor(
    String table,
    String column,
    List<String> ids,
  ) async {
    final rows = await _client.from(table).select(column).inFilter(column, ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row[column] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Set<String>> _idsForCurrentUser(String table, String idColumn) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return {};
    final rows = await _client
        .from(table)
        .select(idColumn)
        .eq('user_id', authUser.id);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row[idColumn] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<void> _setUserDropRelation({
    required String table,
    required String dropId,
    required bool enabled,
    required String actionLabel,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw DropServiceException('Necesitás iniciar sesión para $actionLabel.');
    }
    if (enabled) {
      await _client.from(table).upsert({
        'drop_id': dropId,
        'user_id': authUser.id,
      }, onConflict: 'drop_id,user_id');
      if (table == 'drop_likes') {
        await _notifyDropOwner(
          dropId: dropId,
          actorId: authUser.id,
          type: 'drop_like',
          title: 'Nueva estrella en tu Drop',
          body: 'Le dieron una estrella a tu Drop.',
          dedupe: true,
        );
      }
    } else {
      await _client
          .from(table)
          .delete()
          .eq('drop_id', dropId)
          .eq('user_id', authUser.id);
    }
    LocalDropService.revision.value++;
  }

  Future<void> _notifyDropOwner({
    required String dropId,
    required String actorId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
    bool dedupe = true,
  }) async {
    try {
      final rows = await _client
          .from('drops')
          .select('author_id')
          .eq('id', dropId)
          .filter('deleted_at', 'is', null)
          .limit(1);
      final dropRows = rows.cast<Map<String, dynamic>>();
      if (dropRows.isEmpty) return;
      final recipientId = dropRows.first['author_id'] as String? ?? '';
      await SupabaseNotificationService.createFromClient(
        client: _client,
        recipientId: recipientId,
        actorId: actorId,
        type: type,
        entityType: 'drop',
        entityId: dropId,
        title: title,
        body: body,
        metadata: metadata,
        dedupe: dedupe,
      );
    } catch (error) {
      debugPrint('NOTIFICATION_CREATE_DROP_ERROR dropId=$dropId error=$error');
    }
  }

  Future<Map<String, int>> _commentCounts(List<String> ids) async {
    final rows = await _client
        .from('drop_comments')
        .select('drop_id')
        .filter('deleted_at', 'is', null)
        .inFilter('drop_id', ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row['drop_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  List<PostComment> _commentsFromRows(List<Map<String, dynamic>> rows) {
    final rowsByParent = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final parentId = row['parent_id'] as String? ?? '';
      rowsByParent.putIfAbsent(parentId, () => []).add(row);
    }
    PostComment buildComment(Map<String, dynamic> row) {
      final comment = _commentFromRow(row);
      return comment.copyWith(
        replies: (rowsByParent[comment.id] ?? const [])
            .map(buildComment)
            .toList(growable: false),
      );
    }

    return (rowsByParent[''] ?? const [])
        .map(buildComment)
        .toList(growable: false);
  }

  PostComment _commentFromRow(
    Map<String, dynamic> row, {
    AuthUser? fallbackAuthor,
  }) {
    final currentUserId = _client.auth.currentUser?.id;
    final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    return PostComment(
      id: row['id'] as String? ?? '',
      parentId: row['parent_id'] as String? ?? '',
      authorId: row['author_id'] as String? ?? '',
      author: _string(profile, 'name', fallbackAuthor?.name ?? 'Fan Hallyu'),
      username: _string(
        profile,
        'username',
        fallbackAuthor?.username ?? '@fan',
      ),
      avatarAsset: _string(
        profile,
        'avatar_url',
        _string(
          profile,
          'avatar_asset',
          fallbackAuthor?.avatarAsset ?? 'assets/demo-users/user-01.jpg',
        ),
      ),
      body: row['body'] as String? ?? '',
      time: _relativeTime(createdAt),
      isOwn: currentUserId != null && row['author_id'] == currentUserId,
    );
  }

  DropClip _dropFromRow(
    Map<String, dynamic> row, {
    required int likes,
    required int comments,
    required List<ContentUserTag> tags,
    required List<ContentArtistTag> artistTags,
    required bool isOwn,
  }) {
    final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    final caption = row['caption'] as String? ?? '';
    final artistName = row['artist_name'] as String? ?? '';
    return DropClip(
      id: row['id'] as String? ?? '',
      title: caption.isEmpty ? 'Drop HallyuHub' : caption,
      artist: artistName.isEmpty ? 'Artista etiquetado' : artistName,
      creator: _string(profile, 'username', '@fan'),
      creatorId: row['author_id'] as String? ?? '',
      creatorName: _string(profile, 'name', 'Fan Hallyu'),
      creatorAvatarAsset: _string(
        profile,
        'avatar_url',
        _string(profile, 'avatar_asset', 'assets/demo-users/user-01.jpg'),
      ),
      audio: row['audio'] as String? ?? 'Audio original',
      imageAsset: _string(
        row,
        'thumbnail_url',
        'assets/demo-posts/post-08.jpg',
      ),
      views: '0',
      viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      likes: '$likes',
      comments: '$comments',
      groupId: row['group_id'] as String? ?? '',
      artistId: row['artist_id'] as String? ?? '',
      caption: caption,
      location: row['location'] as String? ?? '',
      videoPath: row['video_url'] as String? ?? '',
      videoDurationSeconds: (row['duration_seconds'] as num?)?.toDouble(),
      filter: row['filter'] as String? ?? 'Original',
      taggedPeople: tags
          .map((tag) => tag.displayUsername)
          .where((username) => username.isNotEmpty)
          .toList(growable: false),
      taggedUserIds: tags
          .map((tag) => tag.taggedUserId)
          .toList(growable: false),
      taggedEntities: artistTags
          .map((tag) => tag.entity)
          .whereType<KpopEntity>()
          .toList(growable: false),
      createdAt: createdAt,
      repostedByUserId: row['reposted_by_user_id'] as String? ?? '',
      repostedByUsername: row['reposted_by_username'] as String? ?? '',
      repostedAt: DateTime.tryParse(
        row['reposted_at'] as String? ?? '',
      ),
      isOwn: isOwn,
    );
  }

  Future<Map<String, List<ContentArtistTag>>> _artistTagsFor({
    required ProfileContentType contentType,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('content_artist_tags')
          .select(
            'content_type,content_id,entity_id,tagged_by,created_at,'
            'entity:entity_id(id,entity_type,name,normalized_name,aliases,bio,'
            'image_url,image_source,image_license,attribution,is_verified)',
          )
          .eq('content_type', contentType.key)
          .inFilter('content_id', ids);
      final grouped = <String, List<ContentArtistTag>>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final contentId = row['content_id'] as String? ?? '';
        if (contentId.isEmpty) continue;
        final entityId = row['entity_id'] as String? ?? '';
        if (entityId.isEmpty) continue;
        final entityRow = (row['entity'] as Map?)?.cast<String, dynamic>();
        grouped
            .putIfAbsent(contentId, () => [])
            .add(
              ContentArtistTag(
                contentType: contentType,
                contentId: contentId,
                entityId: entityId,
                taggedBy: row['tagged_by'] as String? ?? '',
                entity: entityRow == null ? null : _entityFromTag(entityRow),
                createdAt: DateTime.tryParse(
                  row['created_at'] as String? ?? '',
                ),
              ),
            );
      }
      return hydrateContentArtistTags(client: _client, grouped: grouped);
    } catch (error) {
      debugPrint('DROP_ARTIST_TAGS_RESTORE_ERROR $error');
      return const {};
    }
  }

  Future<Map<String, List<ContentArtistTag>>> _resolveDropArtistTags(
    List<Map<String, dynamic>> dropRows,
    Map<String, List<ContentArtistTag>> storedTags,
  ) async {
    final resolved = <String, List<ContentArtistTag>>{
      for (final entry in storedTags.entries)
        entry.key: List<ContentArtistTag>.from(entry.value),
    };
    final needsCatalog = dropRows.any((row) {
      final dropId = row['id'] as String? ?? '';
      final tags = resolved[dropId] ?? const <ContentArtistTag>[];
      if (tags.isEmpty || tags.any((tag) => tag.entity == null)) return true;
      final storedArtistId = (row['artist_id'] as String? ?? '').trim();
      final primaryKeys = <String>{
        _entityLookupKey(storedArtistId),
        _entityLookupKey(row['artist_name'] as String? ?? ''),
      }..remove('');
      if (storedArtistId.isEmpty && primaryKeys.isEmpty) return false;
      return !tags.any((tag) {
        if (storedArtistId.isNotEmpty && tag.entityId == storedArtistId) {
          return true;
        }
        final entity = tag.entity;
        if (entity == null) return false;
        final entityKeys = <String>{
          _entityLookupKey(entity.name),
          _entityLookupKey(entity.normalizedName),
          ...entity.aliases.map(_entityLookupKey),
        }..remove('');
        return primaryKeys.any(entityKeys.contains);
      });
    });
    if (!needsCatalog) return resolved;

    final catalog = await _restoreEntityCatalog();
    if (catalog.isEmpty) return resolved;
    final byId = {for (final entity in catalog) entity.id: entity};
    final byKey = <String, List<KpopEntity>>{};
    for (final entity in catalog) {
      final keys = <String>{
        _entityLookupKey(entity.name),
        _entityLookupKey(entity.normalizedName),
        ...entity.aliases.map(_entityLookupKey),
      }..remove('');
      for (final key in keys) {
        byKey.putIfAbsent(key, () => []).add(entity);
      }
    }

    for (final row in dropRows) {
      final dropId = row['id'] as String? ?? '';
      if (dropId.isEmpty) continue;
      final existing = resolved[dropId] ?? const <ContentArtistTag>[];
      final enriched = existing
          .map(
            (tag) => tag.entity != null || byId[tag.entityId] == null
                ? tag
                : ContentArtistTag(
                    contentType: tag.contentType,
                    contentId: tag.contentId,
                    entityId: tag.entityId,
                    taggedBy: tag.taggedBy,
                    entity: byId[tag.entityId],
                    createdAt: tag.createdAt,
                  ),
          )
          .toList(growable: true);

      final candidates = <String, KpopEntity>{};
      final storedArtistId = (row['artist_id'] as String? ?? '').trim();
      final exactIdEntity = byId[storedArtistId];
      if (exactIdEntity != null) candidates[exactIdEntity.id] = exactIdEntity;
      for (final rawValue in <String>[
        storedArtistId,
        row['artist_name'] as String? ?? '',
      ]) {
        final key = _entityLookupKey(rawValue);
        if (key.isEmpty) continue;
        final matches = byKey[key] ?? const <KpopEntity>[];
        if (matches.length == 1) candidates[matches.single.id] = matches.single;
      }
      if (candidates.length == 1) {
        final primary = candidates.values.single;
        if (!enriched.any((tag) => tag.entityId == primary.id)) {
          enriched.add(
            ContentArtistTag(
              contentType: ProfileContentType.drop,
              contentId: dropId,
              entityId: primary.id,
              taggedBy: row['author_id'] as String? ?? '',
              entity: primary,
              createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
            ),
          );
        }
      }
      if (enriched.isNotEmpty) resolved[dropId] = enriched;
    }
    return resolved;
  }

  Future<List<KpopEntity>> _restoreEntityCatalog() async {
    final now = DateTime.now();
    final cachedAt = _entityCatalogCachedAt;
    final cached = _entityCatalogCache;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < const Duration(minutes: 5)) {
      return cached;
    }
    try {
      final rows = await _client
          .from('kpop_entities')
          .select(
            'id,entity_type,name,normalized_name,aliases,bio,image_url,'
            'image_source,image_license,attribution,fandom_name,is_verified',
          )
          .limit(1000);
      final entities = rows
          .cast<Map<String, dynamic>>()
          .map(_entityFromTag)
          .where((entity) => entity.id.trim().isNotEmpty)
          .toList(growable: false);
      _entityCatalogCache = entities;
      _entityCatalogCachedAt = now;
      return entities;
    } catch (error) {
      debugPrint('DROP_ENTITY_CATALOG_RESTORE_ERROR $error');
      return cached ?? const <KpopEntity>[];
    }
  }

  String _entityLookupKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  KpopEntity _entityFromTag(Map<String, dynamic> row) {
    return KpopEntity(
      id: row['id'] as String? ?? '',
      type: KpopEntityType.fromKey(row['entity_type'] as String? ?? 'artist'),
      name: row['name'] as String? ?? 'Artista',
      normalizedName: row['normalized_name'] as String? ?? '',
      aliases: (row['aliases'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      bio: row['bio'] as String? ?? '',
      imageUrl: row['image_url'] as String? ?? '',
      imageSource: row['image_source'] as String? ?? '',
      imageLicense: row['image_license'] as String? ?? '',
      attribution: row['attribution'] as String? ?? '',
      fandomName: row['fandom_name'] as String? ?? '',
      verified: row['is_verified'] as bool? ?? false,
    );
  }

  Future<Map<String, List<ContentUserTag>>> _userTagsFor({
    required ProfileContentType contentType,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('content_user_tags')
          .select(
            'content_type,content_id,tagged_user_id,tagged_by,created_at,'
            'profile:tagged_user_id(id,name,username,bio,avatar_asset,avatar_url,'
            'fandom,content_region,location_visibility,'
            'favorite_group)',
          )
          .eq('content_type', contentType.key)
          .inFilter('content_id', ids);
      final grouped = <String, List<ContentUserTag>>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final contentId = row['content_id'] as String? ?? '';
        if (contentId.isEmpty) continue;
        final taggedUserId = row['tagged_user_id'] as String? ?? '';
        if (taggedUserId.isEmpty) continue;
        final profileRow = (row['profile'] as Map?)?.cast<String, dynamic>();
        grouped
            .putIfAbsent(contentId, () => [])
            .add(
              ContentUserTag(
                contentType: contentType,
                contentId: contentId,
                taggedUserId: taggedUserId,
                taggedBy: row['tagged_by'] as String? ?? '',
                profile: profileRow == null
                    ? null
                    : _profileFromTag(profileRow),
                createdAt: DateTime.tryParse(
                  row['created_at'] as String? ?? '',
                ),
              ),
            );
      }
      return grouped;
    } catch (error) {
      debugPrint('DROP_USER_TAGS_RESTORE_ERROR $error');
      return const {};
    }
  }

  CommunityProfile _profileFromTag(Map<String, dynamic> row) {
    final name = _string(row, 'name', 'Hallyu Fan');
    final fandom = _string(row, 'fandom', 'Hallyu');
    return CommunityProfile(
      id: row['id'] as String? ?? '',
      name: name,
      username: _normalizeUsername(_string(row, 'username', name)),
      city: _string(row, 'city', _string(row, 'country', '')),
      country: _string(row, 'country', ''),
      fandom: fandom,
      favoriteGroup: _string(row, 'favorite_group', 'K-pop'),
      bio: _string(row, 'bio', ''),
      avatarAsset: _string(
        row,
        'avatar_url',
        _string(row, 'avatar_asset', 'assets/demo-users/user-01.jpg'),
      ),
      followers: '0',
      following: '0',
      posts: '0',
      starsReceived: '0',
      level: 1,
      coverAsset: 'assets/demo-posts/post-01.jpg',
      colors: const [Color(0xFF39E6E6), Color(0xFFEF4F7A), Color(0xFF080313)],
      online: false,
    );
  }

  String _normalizeUsername(String username) {
    final cleaned = username.replaceFirst('@', '').trim();
    return cleaned.isEmpty ? '@fan' : '@$cleaned';
  }

  String _string(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Ahora';
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  void _log(String event, Map<String, Object?> data) {
    debugPrint(
      '$event ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }
}

class _StoredDropVideo {
  const _StoredDropVideo({
    required this.bucket,
    required this.path,
    required this.publicUrl,
    required this.fileSize,
    required this.contentType,
  });

  final String bucket;
  final String path;
  final String publicUrl;
  final int fileSize;
  final String contentType;
}
