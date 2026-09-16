import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_post_service.dart';
import 'media_upload_limits.dart';
import 'supabase_artist_tag_hydrator.dart';
import 'supabase_notification_service.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

class SupabasePostService extends LocalPostService {
  SupabasePostService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;
  static const _maxImageBytes = MediaUploadLimits.imageBytes;
  static const _maxVideoBytes = MediaUploadLimits.postVideoBytes;
  static const _maxMediaItems = MediaUploadLimits.maxPostMediaItems;
  static const _postSelectColumns =
      'id,author_id,caption,location,privacy,artist_id,music,filter_index,'
      'tagged_people,tags,created_at,'
      'profiles:author_id(id,name,username,avatar_asset,avatar_url),'
      'post_media(id,media_type,storage_bucket,storage_path,public_url,sort_order,transform)';

  @override
  bool get usesRealPosts => true;

  @override
  Future<List<HubPost>> restorePosts({
    int limit = 24,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    bool homeFeed = false,
    Set<String> followedAuthorIds = const <String>{},
    Set<String> followedEntityIds = const <String>{},
  }) async {
    final stopwatch = Stopwatch()..start();
    final currentUserId = _client.auth.currentUser?.id;
    final effectiveAuthorId = onlyCurrentUser ? currentUserId : authorId;
    _logPerformance(
      'PERF_POSTS_FETCH_START limit=$limit offset=$offset authorId=${effectiveAuthorId ?? ''} homeFeed=$homeFeed followedEntities=${followedEntityIds.length}',
    );
    final useHomeFeed =
        homeFeed && effectiveAuthorId == null && currentUserId != null;
    final postRows = useHomeFeed
        ? await _restoreHomeFeedRows(limit: limit, offset: offset)
        : await _restorePostRows(
            limit: limit,
            offset: offset,
            authorId: effectiveAuthorId,
          );
    if (postRows.isEmpty) {
      _logPerformance(
        'PERF_POSTS_FETCH_OK count=0 elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return [];
    }
    final ids = postRows.map((row) => row['id'] as String).toList();
    final likes = await _countsFor('post_likes', 'post_id', ids);
    final saves = await _countsFor('post_saves', 'post_id', ids);
    final comments = await _commentCounts(ids);
    final artistTags = await _artistTagsFor(
      contentType: ProfileContentType.post,
      contentIds: ids,
    );
    final likedByMe = currentUserId == null
        ? <String>{}
        : await _idsForCurrentUser('post_likes', ids);
    final savedByMe = currentUserId == null
        ? <String>{}
        : await _idsForCurrentUser('post_saves', ids);

    final posts = postRows
        .map(
          (row) => _postFromRow(
            row,
            likes: likes[row['id']] ?? 0,
            saves: saves[row['id']] ?? 0,
            comments: comments[row['id']] ?? 0,
            isOwn: currentUserId != null && row['author_id'] == currentUserId,
            likedByCurrentUser: likedByMe.contains(row['id']),
            savedByCurrentUser: savedByMe.contains(row['id']),
            artistTags: artistTags[row['id']] ?? const [],
          ),
        )
        .toList(growable: false);
    _logPerformance(
      'PERF_POSTS_FETCH_OK count=${posts.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return posts;
  }

  @override
  Future<List<HubPost>> restorePostsByIds(
    Iterable<String> postIds, {
    int limit = 100,
  }) async {
    final ids = postIds.toSet();
    if (ids.isEmpty) return const [];
    final rows = await _restorePostRows(
      limit: limit,
      offset: 0,
      postIds: ids,
    );
    if (rows.isEmpty) return const [];
    return _restorePostsFromRows(rows);
  }

  Future<List<HubPost>> _restorePostsFromRows(
    List<Map<String, dynamic>> postRows,
  ) async {
    final currentUserId = _client.auth.currentUser?.id;
    final ids = postRows.map((row) => row['id'] as String).toList();
    final likes = await _countsFor('post_likes', 'post_id', ids);
    final saves = await _countsFor('post_saves', 'post_id', ids);
    final comments = await _commentCounts(ids);
    final artistTags = await _artistTagsFor(
      contentType: ProfileContentType.post,
      contentIds: ids,
    );
    final likedByMe = currentUserId == null
        ? <String>{}
        : await _idsForCurrentUser('post_likes', ids);
    final savedByMe = currentUserId == null
        ? <String>{}
        : await _idsForCurrentUser('post_saves', ids);
    return postRows
        .map(
          (row) => _postFromRow(
            row,
            likes: likes[row['id']] ?? 0,
            saves: saves[row['id']] ?? 0,
            comments: comments[row['id']] ?? 0,
            isOwn: currentUserId != null && row['author_id'] == currentUserId,
            likedByCurrentUser: likedByMe.contains(row['id']),
            savedByCurrentUser: savedByMe.contains(row['id']),
            artistTags: artistTags[row['id']] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _restorePostRows({
    required int limit,
    required int offset,
    String? authorId,
    Set<String> postIds = const <String>{},
  }) async {
    var query = _client
        .from('posts')
        .select(_postSelectColumns)
        .eq('status', 'published')
        .filter('deleted_at', 'is', null);
    if (authorId != null && authorId.isNotEmpty) {
      query = query.eq('author_id', authorId);
    }
    if (postIds.isNotEmpty) query = query.inFilter('id', postIds.toList());
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _restoreHomeFeedRows({
    required int limit,
    required int offset,
  }) async {
    try {
      debugPrint('HOME_FEED_RPC_START limit=$limit offset=$offset');
      final response = await _client.rpc(
        'get_home_feed',
        params: {'limit_count': limit, 'offset_count': offset},
      );
      final ids = response is List
          ? response
                .whereType<Map>()
                .map(
                  (row) =>
                      row['post_id'] as String? ?? row['id'] as String? ?? '',
                )
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      debugPrint('HOME_FEED_RPC_RESULT count=${ids.length}');
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('posts')
          .select(_postSelectColumns)
          .inFilter('id', ids)
          .eq('status', 'published')
          .filter('deleted_at', 'is', null);
      final rowsById = {
        for (final row in rows.cast<Map<String, dynamic>>())
          row['id'] as String: row,
      };
      return ids
          .map((id) => rowsById[id])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (error) {
      debugPrint('HOME_FEED_RPC_ERROR $error');
      return const [];
    }
  }

  @override
  Future<HubPost> publish({
    required AuthUser author,
    required PostDraft draft,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const PostServiceException(
        'Necesitás iniciar sesión para publicar.',
      );
    }

    final mediaItems = draft.effectiveMediaItems;
    if (mediaItems.length > _maxMediaItems) {
      throw const PostServiceException(
        'Por ahora solo podés subir hasta 6 archivos por publicación.',
      );
    }
    final insertedPost = await _client
        .from('posts')
        .insert({
          'author_id': authUser.id,
          'caption': draft.caption,
          'location': draft.location,
          'privacy': draft.privacy,
          'artist_id': draft.artist,
          'music': draft.music,
          'filter_index': draft.filterIndex,
          'tagged_people': draft.taggedPeople,
          'tags': draft.tags,
          'status': 'published',
        })
        .select('id,created_at')
        .single();

    final postId = insertedPost['id'] as String;
    final mediaRows = <Map<String, dynamic>>[];
    final uploadedMedia = <_StoredPostMedia>[];
    if (mediaItems.isNotEmpty) {
      try {
        for (var index = 0; index < mediaItems.length; index += 1) {
          final item = mediaItems[index];
          final stored = await _storeMedia(authUser.id, postId, item, index);
          uploadedMedia.add(stored);
          mediaRows.add({
            'post_id': postId,
            'media_type': item.type.name,
            'storage_bucket': stored.bucket,
            'storage_path': stored.path,
            'public_url': stored.publicUrl,
            'sort_order': index,
            'transform': _transformFor(item, stored),
          });
        }
        await _client.from('post_media').insert(mediaRows);
      } catch (error) {
        debugPrint('POST_MEDIA_PUBLISH_ERROR $error');
        await _cleanupFailedPublish(authUser.id, postId, uploadedMedia);
        if (error is PostServiceException) rethrow;
        throw const PostServiceException(
          'No pudimos subir todos los archivos. Revisá conexión y probá de nuevo.',
        );
      }
    }
    LocalPostService.revision.value++;

    final first = mediaItems.firstOrNull;
    return HubPost(
      id: postId,
      authorId: authUser.id,
      author: author.name,
      username: author.username,
      avatarAsset: author.avatarAsset,
      imageAsset: mediaRows.isEmpty
          ? ''
          : mediaRows.first['public_url'] as String? ?? first?.imageAsset ?? '',
      mediaPath: mediaRows.isEmpty
          ? ''
          : mediaRows.first['public_url'] as String? ?? first?.mediaPath ?? '',
      containsVideo: first?.isVideo ?? false,
      videoTrimStartSeconds: first?.videoTrimStartSeconds ?? 0,
      videoTrimEndSeconds: first?.videoTrimEndSeconds,
      videoMuted: first?.videoMuted ?? true,
      mediaItems: mediaItems
          .asMap()
          .entries
          .map(
            (entry) => entry.value.copyWith(
              imageAsset: mediaRows[entry.key]['public_url'] as String? ?? '',
              clearImageBytes: true,
              mediaPath: mediaRows[entry.key]['public_url'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      mediaScale: first?.mediaScale ?? 1,
      mediaOffset: first?.mediaOffset ?? Offset.zero,
      mediaRotation: first?.mediaRotation ?? 0,
      music: draft.music,
      musicAsset: draft.musicAsset,
      filterIndex: draft.filterIndex,
      taggedPeople: draft.taggedPeople,
      taggedUserIds: draft.taggedUserIds,
      taggedEntities: draft.taggedEntities,
      artist: draft.artist,
      privacy: draft.privacy,
      caption: draft.caption,
      tags: draft.tags,
      likes: '0',
      comments: '0',
      mood: mediaItems.any((item) => item.isVideo)
          ? 'Video'
          : mediaItems.isEmpty
          ? 'Texto'
          : 'Nuevo',
      time: 'Ahora',
      shares: '0',
      saves: '0',
      location: draft.location,
      createdAt: DateTime.tryParse(insertedPost['created_at'] as String? ?? ''),
      isOwn: true,
    );
  }

  @override
  Future<void> updateAuthorProfile(AuthUser author) async {
    LocalPostService.revision.value++;
  }

  @override
  Future<void> deletePost(String id) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const PostServiceException('Necesitás iniciar sesión.');
    }
    _logPerformance(
      'POST_DELETE_RPC_START postId=$id currentUser=${authUser.id}',
    );
    try {
      await _client.rpc('delete_my_post', params: {'p_post_id': id});
      _logPerformance('POST_DELETE_RPC_OK postId=$id');
    } catch (error) {
      _logPerformance('POST_DELETE_RPC_ERROR postId=$id error=$error');
      try {
        _logPerformance('POST_DELETE_FALLBACK_START postId=$id');
        final now = DateTime.now().toUtc().toIso8601String();
        await _client
            .from('posts')
            .update({'deleted_at': now, 'updated_at': now})
            .eq('id', id)
            .eq('author_id', authUser.id)
            .filter('deleted_at', 'is', null);
        _logPerformance('POST_DELETE_FALLBACK_OK postId=$id');
      } catch (fallbackError) {
        _logPerformance(
          'POST_DELETE_FALLBACK_ERROR postId=$id error=$fallbackError',
        );
        throw const PostServiceException(
          'No pudimos eliminar la publicación. Revisá permisos y probá de nuevo.',
        );
      }
    }
    final stillVisible = await _postStillVisible(id);
    _logPerformance('POST_DELETE_VERIFY postId=$id stillVisible=$stillVisible');
    if (stillVisible) {
      throw const PostServiceException(
        'No pudimos confirmar la eliminación en Supabase. Probá de nuevo.',
      );
    }
    LocalPostService.revision.value++;
  }

  Future<bool> _postStillVisible(String id) async {
    try {
      final rows = await _client
          .from('posts')
          .select('id')
          .eq('id', id)
          .filter('deleted_at', 'is', null)
          .limit(1);
      return rows.cast<Map<String, dynamic>>().isNotEmpty;
    } catch (error) {
      _logPerformance('POST_DELETE_VERIFY_ERROR postId=$id error=$error');
      throw const PostServiceException(
        'No pudimos confirmar la eliminación. Revisá conexión y probá de nuevo.',
      );
    }
  }

  @override
  Future<Set<String>> restoreLikedPostIds() async =>
      _idsForCurrentUser('post_likes');

  @override
  Future<Set<String>> restoreSavedPostIds() async =>
      _idsForCurrentUser('post_saves');

  @override
  Future<void> setPostLiked(String postId, bool liked) async {
    await _setUserPostRelation(
      table: 'post_likes',
      postId: postId,
      enabled: liked,
      actionLabel: 'dar estrella',
    );
  }

  @override
  Future<void> setPostSaved(String postId, bool saved) async {
    await _setUserPostRelation(
      table: 'post_saves',
      postId: postId,
      enabled: saved,
      actionLabel: 'guardar',
    );
  }

  @override
  Future<List<PostComment>> restoreComments(String postId) async {
    await _ensurePostAvailable(postId);
    final rows = await _client
        .from('comments')
        .select(
          'id,parent_id,author_id,body,created_at,'
          'profiles:author_id(id,name,username,avatar_asset,avatar_url)',
        )
        .eq('content_type', 'post')
        .eq('content_id', postId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: true);
    return _commentsFromRows(rows.cast<Map<String, dynamic>>());
  }

  @override
  Future<PostComment> addComment({
    required AuthUser author,
    required String postId,
    required String body,
    String parentId = '',
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const PostServiceException(
        'Necesitás iniciar sesión para comentar.',
      );
    }
    final cleaned = body.trim();
    if (cleaned.isEmpty) {
      throw const PostServiceException('Escribí un comentario primero.');
    }
    if (cleaned.length > LocalPostService.maxCommentLength) {
      throw const PostServiceException('El comentario es demasiado largo.');
    }
    await _ensurePostAvailable(postId);
    final row = await _client
        .from('comments')
        .insert({
          'content_type': 'post',
          'content_id': postId,
          'parent_id': parentId.isEmpty ? null : parentId,
          'author_id': authUser.id,
          'body': cleaned,
        })
        .select(
          'id,parent_id,author_id,body,created_at,'
          'profiles:author_id(id,name,username,avatar_asset,avatar_url)',
        )
        .single();
    await _notifyPostOwner(
      postId: postId,
      actorId: authUser.id,
      type: 'post_comment',
      title: 'Nuevo comentario',
      body: '${author.name} comentó tu publicación.',
      metadata: {
        'comment_id': row['id'] as String? ?? '',
        'preview': cleaned.length > 140 ? cleaned.substring(0, 140) : cleaned,
      },
      dedupe: true,
    );
    LocalPostService.revision.value++;
    return _commentFromRow(row, fallbackAuthor: author);
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const PostServiceException(
        'Necesitás iniciar sesión para borrar comentarios.',
      );
    }
    try {
      await _client.rpc(
        'delete_my_comment',
        params: {'p_comment_id': commentId},
      );
    } catch (_) {
      await _client
          .from('comments')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', commentId)
          .eq('author_id', authUser.id);
    }
    LocalPostService.revision.value++;
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

  Future<Set<String>> _idsForCurrentUser(
    String table, [
    List<String>? onlyPostIds,
  ]) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return {};
    var query = _client
        .from(table)
        .select('post_id')
        .eq('user_id', authUser.id);
    if (onlyPostIds != null && onlyPostIds.isNotEmpty) {
      query = query.inFilter('post_id', onlyPostIds);
    }
    final rows = await query;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['post_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<void> _setUserPostRelation({
    required String table,
    required String postId,
    required bool enabled,
    required String actionLabel,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw PostServiceException('Necesitás iniciar sesión para $actionLabel.');
    }
    await _ensurePostAvailable(postId);
    if (enabled) {
      await _client.from(table).upsert({
        'post_id': postId,
        'user_id': authUser.id,
      }, onConflict: 'post_id,user_id');
      if (table == 'post_likes') {
        await _notifyPostOwner(
          postId: postId,
          actorId: authUser.id,
          type: 'post_like',
          title: 'Nueva estrella',
          body: 'Le dieron una estrella a tu publicación.',
          dedupe: true,
        );
      }
    } else {
      await _client
          .from(table)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', authUser.id);
    }
    LocalPostService.revision.value++;
  }

  Future<void> _ensurePostAvailable(String postId) async {
    try {
      final rows = await _client
          .from('posts')
          .select('id')
          .eq('id', postId)
          .eq('status', 'published')
          .filter('deleted_at', 'is', null)
          .limit(1);
      if (rows.cast<Map<String, dynamic>>().isEmpty) {
        throw const PostServiceException(
          'Esta publicación ya no está disponible.',
        );
      }
    } on PostServiceException {
      rethrow;
    } catch (error) {
      debugPrint('POST_AVAILABILITY_ERROR postId=$postId error=$error');
      throw const PostServiceException(
        'No pudimos confirmar si la publicación sigue disponible.',
      );
    }
  }

  Future<void> _notifyPostOwner({
    required String postId,
    required String actorId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
    bool dedupe = true,
  }) async {
    try {
      final rows = await _client
          .from('posts')
          .select('author_id')
          .eq('id', postId)
          .filter('deleted_at', 'is', null)
          .limit(1);
      final postRows = rows.cast<Map<String, dynamic>>();
      if (postRows.isEmpty) return;
      final recipientId = postRows.first['author_id'] as String? ?? '';
      await SupabaseNotificationService.createFromClient(
        client: _client,
        recipientId: recipientId,
        actorId: actorId,
        type: type,
        entityType: 'post',
        entityId: postId,
        title: title,
        body: body,
        metadata: metadata,
        dedupe: dedupe,
      );
    } catch (error) {
      debugPrint('NOTIFICATION_CREATE_POST_ERROR postId=$postId error=$error');
    }
  }

  Future<Map<String, int>> _commentCounts(List<String> ids) async {
    final rows = await _client
        .from('comments')
        .select('content_id')
        .eq('content_type', 'post')
        .filter('deleted_at', 'is', null)
        .inFilter('content_id', ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row['content_id'] as String?;
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

  Future<_StoredPostMedia> _storeMedia(
    String userId,
    String postId,
    PostMediaItem item,
    int index,
  ) async {
    final bytes = await _mediaBytes(item);
    if (bytes == null) {
      final fallback = item.imageAsset.isNotEmpty
          ? item.imageAsset
          : item.mediaPath;
      return _StoredPostMedia(
        bucket: fallback.startsWith('assets/') ? 'asset' : 'external',
        path: fallback,
        publicUrl: fallback,
      );
    }

    if (bytes.isEmpty) {
      throw const PostServiceException(
        'El archivo parece estar vacío o no se pudo leer.',
      );
    }
    if (item.isVideo && bytes.lengthInBytes > _maxVideoBytes) {
      throw const PostServiceException(
        'El video supera el límite de 100 MB del acceso anticipado.',
      );
    }
    if (!item.isVideo && bytes.lengthInBytes > _maxImageBytes) {
      throw const PostServiceException('La imagen supera el límite de 10 MB.');
    }
    if (!item.isVideo &&
        MediaUploadLimits.detectImageContentType(bytes) == null) {
      throw const PostServiceException(
        'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
      );
    }

    final type = item.isVideo
        ? _videoContentType(item)
        : _imageContentType(bytes);
    final extension = _extensionForContentType(type);
    final path =
        '$userId/$postId/media-$index-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('post_media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: type,
            upsert: true,
            cacheControl: '3600',
          ),
        );
    return _StoredPostMedia(
      bucket: 'post_media',
      path: path,
      publicUrl: _client.storage.from('post_media').getPublicUrl(path),
      contentType: type,
    );
  }

  Future<Uint8List?> _mediaBytes(PostMediaItem item) async {
    final bytes = item.imageBytes;
    if (bytes != null) return bytes;
    if (!item.isVideo) return null;
    final path = item.mediaPath;
    if (path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      throw const PostServiceException(
        'No pudimos preparar este video. Probá con otro clip más liviano.',
      );
    }
    try {
      return XFile(path).readAsBytes();
    } catch (_) {
      throw const PostServiceException(
        'No pudimos leer el video seleccionado. Probá con otro archivo.',
      );
    }
  }

  Future<void> _cleanupFailedPublish(
    String userId,
    String postId,
    List<_StoredPostMedia> uploadedMedia,
  ) async {
    try {
      await _client
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('author_id', userId);
    } catch (_) {}
    for (final media in uploadedMedia) {
      if (media.bucket != 'post_media' || media.path.isEmpty) continue;
      try {
        await _client.storage.from(media.bucket).remove([media.path]);
      } catch (_) {}
    }
  }

  HubPost _postFromRow(
    Map<String, dynamic> row, {
    required int likes,
    required int saves,
    required int comments,
    required bool isOwn,
    required bool likedByCurrentUser,
    required bool savedByCurrentUser,
    required List<ContentArtistTag> artistTags,
  }) {
    final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final media =
        ((row['post_media'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
          ..sort(
            (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
              (b['sort_order'] as num?)?.toInt() ?? 0,
            ),
          ));
    final mediaItems = media.map(_mediaFromRow).toList(growable: false);
    final first = mediaItems.isEmpty ? null : mediaItems.first;
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    return HubPost(
      id: row['id'] as String,
      authorId: row['author_id'] as String? ?? '',
      author: _string(profile, 'name', 'Hallyu Fan'),
      username: _string(profile, 'username', '@fan'),
      avatarAsset: _string(
        profile,
        'avatar_url',
        _string(profile, 'avatar_asset', ''),
      ),
      imageAsset: first?.imageAsset ?? '',
      mediaPath: first?.mediaPath ?? '',
      containsVideo: first?.isVideo ?? false,
      videoTrimStartSeconds: first?.videoTrimStartSeconds ?? 0,
      videoTrimEndSeconds: first?.videoTrimEndSeconds,
      videoMuted: first?.videoMuted ?? true,
      mediaItems: mediaItems,
      mediaScale: first?.mediaScale ?? 1,
      mediaOffset: first?.mediaOffset ?? Offset.zero,
      mediaRotation: first?.mediaRotation ?? 0,
      music: row['music'] as String? ?? '',
      filterIndex: (row['filter_index'] as num?)?.toInt() ?? 0,
      taggedPeople: _stringList(row['tagged_people']),
      taggedUserIds: const [],
      taggedEntities: artistTags
          .map((tag) => tag.entity)
          .whereType<KpopEntity>()
          .toList(growable: false),
      artist: row['artist_id'] as String? ?? '',
      privacy: row['privacy'] as String? ?? 'Todos',
      caption: row['caption'] as String? ?? '',
      tags: _stringList(row['tags']),
      likes: '$likes',
      comments: '$comments',
      mood: mediaItems.any((item) => item.isVideo) ? 'Video' : 'Post',
      time: _relativeTime(createdAt),
      shares: '0',
      saves: '$saves',
      location: row['location'] as String? ?? '',
      createdAt: createdAt,
      isOwn: isOwn,
      likedByCurrentUser: likedByCurrentUser,
      savedByCurrentUser: savedByCurrentUser,
    );
  }

  Future<Map<String, List<ContentArtistTag>>> _artistTagsFor({
    required ProfileContentType contentType,
    required Iterable<String> contentIds,
  }) async {
    final ids = contentIds.where((id) => id.trim().isNotEmpty).toSet().toList();
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
          .inFilter('content_id', ids)
          .order('created_at', ascending: true);
      final grouped = <String, List<ContentArtistTag>>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final tag = _artistTagFromRow(row);
        if (tag == null) continue;
        grouped.putIfAbsent(tag.contentId, () => []).add(tag);
      }
      return hydrateContentArtistTags(client: _client, grouped: grouped);
    } catch (error) {
      debugPrint('POST_ARTIST_TAGS_RESTORE_ERROR $error');
      return const {};
    }
  }

  ContentArtistTag? _artistTagFromRow(Map<String, dynamic> row) {
    final contentType = ProfileContentType.fromKey(
      row['content_type'] as String? ?? '',
    );
    final contentId = row['content_id'] as String? ?? '';
    final entityId = row['entity_id'] as String? ?? '';
    if (contentType == null || contentId.isEmpty || entityId.isEmpty) {
      return null;
    }
    final entityRow = (row['entity'] as Map?)?.cast<String, dynamic>();
    return ContentArtistTag(
      contentType: contentType,
      contentId: contentId,
      entityId: entityId,
      taggedBy: row['tagged_by'] as String? ?? '',
      entity: entityRow == null ? null : _entityFromRow(entityRow),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  KpopEntity _entityFromRow(Map<String, dynamic> row) {
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

  PostMediaItem _mediaFromRow(Map<String, dynamic> row) {
    final transform = (row['transform'] as Map?)?.cast<String, dynamic>() ?? {};
    final publicUrl = row['public_url'] as String? ?? '';
    return PostMediaItem(
      id: row['id'] as String? ?? '',
      type: PostMediaType.values.byName(
        row['media_type'] as String? ?? PostMediaType.image.name,
      ),
      imageAsset: publicUrl,
      mediaPath: publicUrl,
      fileName: transform['file_name'] as String? ?? '',
      mimeType: transform['mime_type'] as String? ?? '',
      fileSizeBytes: (transform['file_size_bytes'] as num?)?.toInt(),
      mediaScale: (transform['scale'] as num?)?.toDouble() ?? 1,
      mediaOffset: Offset(
        (transform['offset_dx'] as num?)?.toDouble() ?? 0,
        (transform['offset_dy'] as num?)?.toDouble() ?? 0,
      ),
      mediaRotation: (transform['rotation'] as num?)?.toDouble() ?? 0,
      videoTrimStartSeconds: (transform['trim_start'] as num?)?.toDouble() ?? 0,
      videoTrimEndSeconds: (transform['trim_end'] as num?)?.toDouble(),
      videoMuted: transform['muted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _transformFor(
    PostMediaItem item,
    _StoredPostMedia stored,
  ) {
    return {
      'scale': item.mediaScale,
      'offset_dx': item.mediaOffset.dx,
      'offset_dy': item.mediaOffset.dy,
      'rotation': item.mediaRotation,
      'trim_start': item.videoTrimStartSeconds,
      'trim_end': item.videoTrimEndSeconds,
      'muted': item.videoMuted,
      'file_name': item.fileName,
      'mime_type': stored.contentType,
      'file_size_bytes': item.fileSizeBytes ?? item.imageBytes?.lengthInBytes,
    };
  }

  String _imageContentType(Uint8List bytes) {
    final contentType = MediaUploadLimits.detectImageContentType(bytes);
    if (contentType == null) {
      throw const PostServiceException(
        'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
      );
    }
    return contentType;
  }

  String _videoContentType(PostMediaItem item) {
    final mimeType = item.mimeType.toLowerCase();
    if (mimeType == 'video/mp4' ||
        mimeType == 'video/quicktime' ||
        mimeType == 'video/webm') {
      return mimeType;
    }
    final source = '${item.fileName} ${item.mediaPath}'.toLowerCase();
    if (source.contains('.mov')) return 'video/quicktime';
    if (source.contains('.webm')) return 'video/webm';
    if (source.contains('.mp4') || source.contains('.m4v')) {
      return 'video/mp4';
    }
    throw const PostServiceException(
      'Usá un video MP4 o MOV durante el acceso anticipado.',
    );
  }

  String _extensionForContentType(String contentType) {
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'video/mp4' => 'mp4',
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      _ => 'jpg',
    };
  }

  String _string(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return const [];
  }

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Ahora';
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (!sameDay) return _dateLabel(local);
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours} h';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _StoredPostMedia {
  const _StoredPostMedia({
    required this.bucket,
    required this.path,
    required this.publicUrl,
    this.contentType = '',
  });

  final String bucket;
  final String path;
  final String publicUrl;
  final String contentType;
}
