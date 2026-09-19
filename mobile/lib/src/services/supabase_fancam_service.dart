import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_fancam_service.dart';
import 'supabase_artist_tag_hydrator.dart';
import 'supabase_notification_service.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

class SupabaseFancamService extends LocalFancamService {
  SupabaseFancamService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealFancams => true;

  @override
  Future<void> recordView({
    required String fancamId,
    required String playbackSessionId,
  }) async {
    if (fancamId.isEmpty || playbackSessionId.isEmpty) return;
    await _client.rpc(
      'record_fancam_view',
      params: {
        'p_fancam_id': fancamId,
        'p_playback_session_id': playbackSessionId,
      },
    );
  }

  @override
  Future<List<Fancam>> restoreFancams({
    int limit = 24,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    FancamFeedMode feedMode = FancamFeedMode.forYou,
  }) async {
    final stopwatch = Stopwatch()..start();
    final currentUserId = _client.auth.currentUser?.id;
    final effectiveAuthorId = onlyCurrentUser ? currentUserId : authorId;
    _logPerformance(
      'PERF_FANCAMS_FETCH_START limit=$limit offset=$offset authorId=${effectiveAuthorId ?? ''}',
    );
    final fancamRows = await _restoreFeedRows(
      limit: limit,
      offset: offset,
      authorId: effectiveAuthorId,
      feedMode: feedMode,
    );
    if (fancamRows.isEmpty) {
      _logPerformance(
        'PERF_FANCAMS_FETCH_OK count=0 elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return [];
    }
    final ids = fancamRows.map((row) => row['id'] as String).toList();
    final likes = await _countsFor('fancam_likes', 'fancam_id', ids);
    final saves = await _countsFor('fancam_saves', 'fancam_id', ids);
    final comments = await _commentCounts(ids);
    final userTags = await _userTagsFor(
      contentType: ProfileContentType.fancam,
      ids: ids,
    );
    final artistTags = await _artistTagsFor(
      contentType: ProfileContentType.fancam,
      ids: ids,
    );
    final fancams = fancamRows
        .map(
          (row) => _fancamFromRow(
            row,
            likes: likes[row['id']] ?? 0,
            saves: saves[row['id']] ?? 0,
            comments: comments[row['id']] ?? 0,
            viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
            tags: userTags[row['id']] ?? const [],
            artistTags: artistTags[row['id']] ?? const [],
            isOwn: currentUserId != null && row['author_id'] == currentUserId,
          ),
        )
        .toList(growable: false);
    _logPerformance(
      'PERF_FANCAMS_FETCH_OK count=${fancams.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return fancams;
  }

  static const _fancamSelect =
      'id,author_id,caption,artist_name,group_name,group_id,artist_id,'
      'event_name,song_name,tags,audio,location,video_url,storage_bucket,'
      'storage_path,duration_seconds,file_size,thumbnail_url,created_at,'
      'view_count,profiles:author_id(id,name,username,avatar_asset,avatar_url)';

  Future<List<Map<String, dynamic>>> _restoreFeedRows({
    required int limit,
    required int offset,
    required String? authorId,
    required FancamFeedMode feedMode,
  }) async {
    if (authorId != null && authorId.isNotEmpty) {
      return _fetchFancamRows(
        limit: limit,
        offset: offset,
        authorId: authorId,
        orderByViews: false,
      );
    }
    switch (feedMode) {
      case FancamFeedMode.viral:
        return _fetchFancamRows(
          limit: limit,
          offset: offset,
          orderByViews: true,
        );
      case FancamFeedMode.following:
        return _followingRows(limit: limit);
      case FancamFeedMode.forYou:
        return _forYouRows(limit: limit);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFancamRows({
    required int limit,
    required int offset,
    bool orderByViews = false,
    String? authorId,
    String? artistId,
    String? groupId,
  }) async {
    var query = _client
        .from('fancams')
        .select(_fancamSelect)
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

  Future<List<Map<String, dynamic>>> _followingRows({
    required int limit,
  }) async {
    final profileIds = await _followedProfileIds();
    final entityIds = await _followedEntityIds();
    if (profileIds.isEmpty && entityIds.isEmpty) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final id in profileIds) {
      rows.addAll(
        await _fetchFancamRows(limit: limit, offset: 0, authorId: id),
      );
    }
    for (final id in entityIds) {
      rows.addAll(
        await _fetchFancamRows(limit: limit, offset: 0, artistId: id),
      );
      rows.addAll(await _fetchFancamRows(limit: limit, offset: 0, groupId: id));
    }
    return _dedupeRows(rows).take(limit).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _forYouRows({required int limit}) async {
    final profileIds = await _followedProfileIds();
    final entityIds = await _followedEntityIds();
    final rows = <Map<String, dynamic>>[];
    for (final id in entityIds) {
      rows.addAll(
        await _fetchFancamRows(limit: limit, offset: 0, artistId: id),
      );
      rows.addAll(await _fetchFancamRows(limit: limit, offset: 0, groupId: id));
    }
    for (final id in profileIds) {
      rows.addAll(
        await _fetchFancamRows(limit: limit, offset: 0, authorId: id),
      );
    }
    rows.addAll(await _fetchFancamRows(limit: limit, offset: 0));
    rows.addAll(
      await _fetchFancamRows(limit: limit, offset: 0, orderByViews: true),
    );
    return _dedupeRows(rows).take(limit).toList(growable: false);
  }

  static List<Map<String, dynamic>> _dedupeRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) byId.putIfAbsent(id, () => row);
    }
    return byId.values.toList(growable: false);
  }

  @override
  Future<Fancam> publish({
    required AuthUser author,
    required String videoPath,
    required String caption,
    required String artist,
    required String groupId,
    required String artistId,
    Uint8List? videoBytes,
    String videoFileName = '',
    String videoMimeType = '',
    String location = '',
    String duration = '00:30',
    double? videoDurationSeconds,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const FancamServiceException(
        'Necesitás iniciar sesión para subir Fancams.',
      );
    }
    if (videoPath.isEmpty) {
      throw const FancamServiceException('Elegí o grabá un video primero.');
    }
    if (videoDurationSeconds != null &&
        videoDurationSeconds > LocalFancamService.maxVideoDurationSeconds) {
      throw const FancamServiceException(
        'La Fancam supera 5 minutos. Recortala antes de publicarla.',
      );
    }

    _StoredFancamVideo? stored;
    try {
      _log('FANCAM_STORAGE_UPLOAD_START', {
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
      _log('FANCAM_STORAGE_UPLOAD_OK', {
        'bucket': stored.bucket,
        'path': stored.path,
        'contentType': stored.contentType,
        'bytes': stored.fileSize,
      });
    } on FancamServiceException catch (error) {
      _log('FANCAM_UPLOAD_ERROR', {'step': 'storage', 'error': error.message});
      rethrow;
    } catch (error) {
      _log('FANCAM_UPLOAD_ERROR', {'step': 'storage', 'error': '$error'});
      throw const FancamServiceException(
        'No pudimos subir el video. Revisá tu conexión y probá de nuevo.',
      );
    }

    final inserted = await _insertPublishedFancam(
      authorId: authUser.id,
      caption: caption,
      artist: artist,
      groupId: groupId,
      artistId: artistId,
      location: location,
      videoDurationSeconds: videoDurationSeconds,
      stored: stored,
    );
    final fancamId = inserted['id'] as String;
    LocalFancamService.revision.value++;
    return Fancam(
      id: fancamId,
      title: caption.isEmpty ? 'Nueva Fancam' : caption,
      artist: artist.isEmpty ? 'Artista etiquetado' : artist,
      creator: author.username,
      creatorId: authUser.id,
      creatorName: author.name,
      creatorAvatarAsset: author.avatarAsset,
      imageAsset: 'assets/demo-posts/post-03.jpg',
      videoPath: stored.publicUrl,
      duration: _durationLabel(videoDurationSeconds, fallback: duration),
      energy: 'Nuevo',
      caption: caption,
      audio: 'Audio original',
      location: location,
      groupId: groupId,
      artistId: artistId,
      likes: '0',
      comments: '0',
      saves: '0',
      shares: '0',
      taggedPeople: const [],
      taggedUserIds: const [],
      createdAt: DateTime.tryParse(inserted['created_at'] as String? ?? ''),
      isOwn: true,
    );
  }

  @override
  Future<void> deleteFancam(String id) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const FancamServiceException('Necesitás iniciar sesión.');
    }
    try {
      await _client.rpc('delete_my_fancam', params: {'p_fancam_id': id});
    } catch (_) {
      await _client
          .from('fancams')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('author_id', authUser.id);
    }
    LocalFancamService.revision.value++;
  }

  @override
  Future<Set<String>> restoreLikedFancamIds() async =>
      _idsForCurrentUser('fancam_likes', 'fancam_id');

  @override
  Future<Set<String>> restoreSavedFancamIds() async =>
      _idsForCurrentUser('fancam_saves', 'fancam_id');

  @override
  Future<void> setFancamLiked(String fancamId, bool liked) async {
    await _setUserFancamRelation(
      table: 'fancam_likes',
      fancamId: fancamId,
      enabled: liked,
      actionLabel: 'dar estrella',
    );
  }

  @override
  Future<void> setFancamSaved(String fancamId, bool saved) async {
    await _setUserFancamRelation(
      table: 'fancam_saves',
      fancamId: fancamId,
      enabled: saved,
      actionLabel: 'guardar',
    );
  }

  @override
  Future<List<PostComment>> restoreComments(String fancamId) async {
    final rows = await _client
        .from('fancam_comments')
        .select(
          'id,parent_id,author_id,body,created_at,'
          'profiles:author_id(id,name,username,avatar_asset,avatar_url)',
        )
        .eq('fancam_id', fancamId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: true);
    return _commentsFromRows(rows.cast<Map<String, dynamic>>());
  }

  @override
  Future<PostComment> addComment({
    required AuthUser author,
    required String fancamId,
    required String body,
    String parentId = '',
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const FancamServiceException(
        'Necesitás iniciar sesión para comentar.',
      );
    }
    final cleaned = body.trim();
    if (cleaned.isEmpty) {
      throw const FancamServiceException('Escribí un comentario primero.');
    }
    if (cleaned.length > LocalFancamService.maxCommentLength) {
      throw const FancamServiceException('El comentario es demasiado largo.');
    }
    final row = await _client
        .from('fancam_comments')
        .insert({
          'fancam_id': fancamId,
          'parent_id': parentId.isEmpty ? null : parentId,
          'author_id': authUser.id,
          'body': cleaned,
        })
        .select(
          'id,parent_id,author_id,body,created_at,'
          'profiles:author_id(id,name,username,avatar_asset,avatar_url)',
        )
        .single();
    await _notifyFancamOwner(
      fancamId: fancamId,
      actorId: authUser.id,
      type: 'fancam_comment',
      title: 'Nuevo comentario en tu Fancam',
      body: '${author.name} comentó tu Fancam.',
      metadata: {
        'comment_id': row['id'] as String? ?? '',
        'preview': cleaned.length > 140 ? cleaned.substring(0, 140) : cleaned,
      },
      dedupe: true,
    );
    LocalFancamService.revision.value++;
    return _commentFromRow(row, fallbackAuthor: author);
  }

  @override
  Future<void> deleteComment({
    required String fancamId,
    required String commentId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const FancamServiceException(
        'Necesitás iniciar sesión para borrar comentarios.',
      );
    }
    try {
      await _client.rpc(
        'delete_my_fancam_comment',
        params: {'p_comment_id': commentId},
      );
    } catch (_) {
      await _client
          .from('fancam_comments')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', commentId)
          .eq('fancam_id', fancamId)
          .eq('author_id', authUser.id);
    }
    LocalFancamService.revision.value++;
  }

  Future<_StoredFancamVideo> _storeVideo(
    String userId,
    String videoPath, {
    Uint8List? videoBytes,
    String fileName = '',
    String mimeType = '',
  }) async {
    final bytes = videoBytes ?? await _videoBytes(videoPath);
    if (bytes.isEmpty) {
      throw const FancamServiceException(
        'El archivo parece estar vacío o no se pudo leer.',
      );
    }
    if (bytes.lengthInBytes > LocalFancamService.maxVideoBytes) {
      throw const FancamServiceException(
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
        '$userId/fancam_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('fancam_media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );
    return _StoredFancamVideo(
      bucket: 'fancam_media',
      path: path,
      publicUrl: _client.storage.from('fancam_media').getPublicUrl(path),
      fileSize: bytes.lengthInBytes,
      contentType: contentType,
    );
  }

  Future<Uint8List> _videoBytes(String videoPath) async {
    if (videoPath.startsWith('http://') ||
        videoPath.startsWith('https://') ||
        videoPath.startsWith('blob:') ||
        videoPath.startsWith('data:')) {
      throw const FancamServiceException(
        'No pudimos preparar este video. Probá con otro clip más liviano.',
      );
    }
    try {
      return await XFile(videoPath).readAsBytes();
    } catch (_) {
      throw const FancamServiceException(
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
    throw const FancamServiceException(
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

  Future<Map<String, dynamic>> _insertPublishedFancam({
    required String authorId,
    required String caption,
    required String artist,
    required String groupId,
    required String artistId,
    required String location,
    required double? videoDurationSeconds,
    required _StoredFancamVideo stored,
  }) async {
    _log('FANCAM_DB_INSERT_START', {
      'author': authorId,
      'bucket': stored.bucket,
      'path': stored.path,
      'status': 'published',
    });
    try {
      final row = await _client
          .from('fancams')
          .insert({
            'author_id': authorId,
            'caption': caption,
            'artist_name': artist,
            'group_id': groupId,
            'artist_id': artistId,
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
      _log('FANCAM_DB_INSERT_OK', {'id': row['id']});
      return row;
    } catch (error) {
      _log('FANCAM_UPLOAD_ERROR', {'step': 'db_insert', 'error': '$error'});
      await _removeStoredVideo(stored);
      throw const FancamServiceException(
        'El video se subió, pero no pudimos publicar la Fancam. Probá de nuevo.',
      );
    }
  }

  Future<void> _removeStoredVideo(_StoredFancamVideo stored) async {
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

  Future<void> _setUserFancamRelation({
    required String table,
    required String fancamId,
    required bool enabled,
    required String actionLabel,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw FancamServiceException(
        'Necesitás iniciar sesión para $actionLabel.',
      );
    }
    if (enabled) {
      await _client.from(table).upsert({
        'fancam_id': fancamId,
        'user_id': authUser.id,
      }, onConflict: 'fancam_id,user_id');
      if (table == 'fancam_likes') {
        await _notifyFancamOwner(
          fancamId: fancamId,
          actorId: authUser.id,
          type: 'fancam_like',
          title: 'Nueva estrella en tu Fancam',
          body: 'Le dieron una estrella a tu Fancam.',
          dedupe: true,
        );
      }
    } else {
      await _client
          .from(table)
          .delete()
          .eq('fancam_id', fancamId)
          .eq('user_id', authUser.id);
    }
    LocalFancamService.revision.value++;
  }

  Future<void> _notifyFancamOwner({
    required String fancamId,
    required String actorId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
    bool dedupe = true,
  }) async {
    try {
      final rows = await _client
          .from('fancams')
          .select('author_id')
          .eq('id', fancamId)
          .filter('deleted_at', 'is', null)
          .limit(1);
      final fancamRows = rows.cast<Map<String, dynamic>>();
      if (fancamRows.isEmpty) return;
      final recipientId = fancamRows.first['author_id'] as String? ?? '';
      await SupabaseNotificationService.createFromClient(
        client: _client,
        recipientId: recipientId,
        actorId: actorId,
        type: type,
        entityType: 'fancam',
        entityId: fancamId,
        title: title,
        body: body,
        metadata: metadata,
        dedupe: dedupe,
      );
    } catch (error) {
      debugPrint(
        'NOTIFICATION_CREATE_FANCAM_ERROR fancamId=$fancamId error=$error',
      );
    }
  }

  Future<Map<String, int>> _commentCounts(List<String> ids) async {
    final rows = await _client
        .from('fancam_comments')
        .select('fancam_id')
        .filter('deleted_at', 'is', null)
        .inFilter('fancam_id', ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row['fancam_id'] as String?;
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

  Fancam _fancamFromRow(
    Map<String, dynamic> row, {
    required int likes,
    required int saves,
    required int comments,
    required int viewCount,
    required List<ContentUserTag> tags,
    required List<ContentArtistTag> artistTags,
    required bool isOwn,
  }) {
    final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    final caption = row['caption'] as String? ?? '';
    final artistName = row['artist_name'] as String? ?? '';
    return Fancam(
      id: row['id'] as String? ?? '',
      title: caption.isEmpty ? 'Fancam HallyuHub' : caption,
      artist: artistName.isEmpty ? 'Artista etiquetado' : artistName,
      creator: _string(profile, 'username', '@fan'),
      creatorId: row['author_id'] as String? ?? '',
      creatorName: _string(profile, 'name', 'Fan Hallyu'),
      creatorAvatarAsset: _string(
        profile,
        'avatar_url',
        _string(profile, 'avatar_asset', 'assets/demo-users/user-01.jpg'),
      ),
      imageAsset: _string(
        row,
        'thumbnail_url',
        'assets/demo-posts/post-03.jpg',
      ),
      videoPath: row['video_url'] as String? ?? '',
      duration: _durationLabel((row['duration_seconds'] as num?)?.toDouble()),
      energy: _string(row, 'song_name', 'Fancam'),
      caption: caption,
      audio: row['audio'] as String? ?? 'Audio original',
      location: row['location'] as String? ?? '',
      groupId: row['group_id'] as String? ?? '',
      artistId: row['artist_id'] as String? ?? '',
      likes: '$likes',
      comments: '$comments',
      saves: '$saves',
      shares: '0',
      viewCount: viewCount,
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
      debugPrint('FANCAM_ARTIST_TAGS_RESTORE_ERROR $error');
      return const {};
    }
  }

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
      debugPrint('FANCAM_USER_TAGS_RESTORE_ERROR $error');
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

  String _durationLabel(double? seconds, {String fallback = '00:30'}) {
    if (seconds == null || seconds <= 0) return fallback;
    final rounded = seconds.round();
    final minutes = (rounded ~/ 60).toString().padLeft(2, '0');
    final secs = (rounded % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
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

class _StoredFancamVideo {
  const _StoredFancamVideo({
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
