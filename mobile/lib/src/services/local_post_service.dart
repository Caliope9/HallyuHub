import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'media_upload_limits.dart';

enum OutfitFeedMode { forYou, popular, following }

class OutfitFeedItem {
  const OutfitFeedItem({
    required this.post,
    this.categoryKey = 'outfit',
    this.repostedByUsername = '',
    this.repostedAt,
  });

  final HubPost post;
  final String categoryKey;
  final String repostedByUsername;
  final DateTime? repostedAt;

  bool get hasRepostMetadata => repostedByUsername.trim().isNotEmpty;
}

class LocalPostService {
  const LocalPostService();

  static const _postsKey = 'hallyuhub.local-posts.v1';
  static const _likedPostsKey = 'hallyuhub.local-liked-posts.v1';
  static const _savedPostsKey = 'hallyuhub.local-saved-posts.v1';
  static const _commentsKey = 'hallyuhub.local-post-comments.v1';
  static const maxCommentLength = 280;
  static const _maxImageBytes = MediaUploadLimits.imageBytes;
  static const _maxVideoBytes = MediaUploadLimits.postVideoBytes;
  static const _maxMediaItems = MediaUploadLimits.maxPostMediaItems;
  static const _maxPosts = 60;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealPosts => false;

  Future<List<HubPost>> restorePosts({
    int limit = _maxPosts,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    bool homeFeed = false,
    Set<String> followedAuthorIds = const <String>{},
    Set<String> followedEntityIds = const <String>{},
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_postsKey);
    if (stored == null) return [];
    try {
      final posts = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_postFromJson)
          .toList();
      final filtered = onlyCurrentUser
          ? posts.where((post) => post.isOwn).toList()
          : authorId == null || authorId.isEmpty
          ? posts
          : posts.where((post) => post.authorId == authorId).toList();
      return filtered.skip(offset).take(limit).toList(growable: false);
    } catch (_) {
      await preferences.remove(_postsKey);
      return [];
    }
  }

  Future<List<HubPost>> restorePostsByIds(
    Iterable<String> postIds, {
    int limit = 100,
  }) async {
    final ids = postIds.toSet();
    if (ids.isEmpty) return const [];
    final posts = await restorePosts(limit: limit);
    return posts.where((post) => ids.contains(post.id)).toList(growable: false);
  }

  Future<List<OutfitFeedItem>> restoreOutfitFeed({
    OutfitFeedMode mode = OutfitFeedMode.forYou,
    String category = 'all',
    int limit = 24,
    int offset = 0,
  }) async {
    final posts = await restorePosts(limit: 1000);
    final outfits = posts.where(_looksLikeLocalOutfit).toList();
    final filtered = category == 'all'
        ? outfits
        : outfits.where((post) => _matchesLocalOutfitCategory(post, category));
    final sorted = filtered.toList();
    sorted.sort((a, b) {
      final date = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      if (date != 0) return date;
      return b.id.compareTo(a.id);
    });
    return sorted
        .skip(offset)
        .take(limit)
        .map((post) => OutfitFeedItem(
              post: post,
              categoryKey: _localOutfitCategory(post),
            ))
        .toList(growable: false);
  }

  String _localOutfitCategory(HubPost post) {
    final haystack = '${post.caption} ${post.tags.join(' ')}'.toLowerCase();
    for (final category in const ['stage', 'airport', 'casual']) {
      if (haystack.contains('#$category') || haystack.contains(category)) {
        return 'outfit_$category';
      }
    }
    return 'outfit';
  }

  bool _looksLikeLocalOutfit(HubPost post) {
    final haystack = '${post.caption} ${post.tags.join(' ')}'.toLowerCase();
    return haystack.contains('outfit') ||
        haystack.contains('#stage') ||
        haystack.contains('#airport') ||
        haystack.contains('#casual');
  }

  bool _matchesLocalOutfitCategory(HubPost post, String category) {
    final haystack = '${post.caption} ${post.tags.join(' ')}'.toLowerCase();
    return haystack.contains('#$category') || haystack.contains(category);
  }

  Future<HubPost> publish({
    required AuthUser author,
    required PostDraft draft,
  }) async {
    final mediaItems = draft.effectiveMediaItems;
    _validateMediaItems(mediaItems);
    final firstMedia = mediaItems.isEmpty ? null : mediaItems.first;
    final containsVideo = mediaItems.any((item) => item.isVideo);
    final post = HubPost(
      id: 'local-post-${DateTime.now().microsecondsSinceEpoch}',
      authorId: 'local-user',
      author: author.name,
      username: author.username,
      avatarAsset: author.avatarAsset,
      imageAsset: firstMedia?.imageAsset ?? draft.imageAsset,
      imageBytes: firstMedia?.imageBytes ?? draft.imageBytes,
      mediaPath: firstMedia?.mediaPath ?? draft.mediaPath,
      containsVideo: firstMedia?.isVideo ?? draft.containsVideo,
      videoTrimStartSeconds:
          firstMedia?.videoTrimStartSeconds ?? draft.videoTrimStartSeconds,
      videoTrimEndSeconds:
          firstMedia?.videoTrimEndSeconds ?? draft.videoTrimEndSeconds,
      videoMuted: firstMedia?.videoMuted ?? draft.videoMuted,
      mediaItems: mediaItems,
      elements: draft.elements,
      mediaScale: firstMedia?.mediaScale ?? draft.mediaScale,
      mediaOffset: firstMedia?.mediaOffset ?? draft.mediaOffset,
      mediaRotation: firstMedia?.mediaRotation ?? draft.mediaRotation,
      music: draft.music,
      musicAsset: draft.musicAsset,
      filterIndex: draft.filterIndex,
      taggedPeople: draft.taggedPeople,
      taggedUserIds: draft.taggedUserIds,
      artist: draft.artist,
      privacy: draft.privacy,
      caption: draft.caption,
      tags: draft.tags,
      likes: '0',
      comments: '0',
      mood: containsVideo
          ? 'Video'
          : mediaItems.isEmpty
          ? 'Texto'
          : 'Nuevo',
      time: 'Ahora',
      shares: '0',
      saves: '0',
      location: draft.location,
      createdAt: DateTime.now(),
      isOwn: true,
    );
    final posts = await restorePosts();
    posts.insert(0, post);
    await _savePosts(posts);
    revision.value++;
    return post;
  }

  void _validateMediaItems(List<PostMediaItem> mediaItems) {
    if (mediaItems.length > _maxMediaItems) {
      throw const PostServiceException(
        'Por ahora solo podés subir hasta 6 archivos por publicación.',
      );
    }
    for (final item in mediaItems) {
      final bytes = item.imageBytes;
      final knownSize = item.fileSizeBytes ?? bytes?.lengthInBytes;
      if (bytes != null && bytes.isEmpty) {
        throw const PostServiceException(
          'El archivo parece estar vacío o no se pudo leer.',
        );
      }
      if (item.isVideo && knownSize != null && knownSize > _maxVideoBytes) {
        throw const PostServiceException(
          'El video supera el límite de 100 MB del acceso anticipado.',
        );
      }
      if (!item.isVideo && knownSize != null && knownSize > _maxImageBytes) {
        throw const PostServiceException(
          'La imagen supera el límite de 10 MB.',
        );
      }
      if (!item.isVideo &&
          bytes != null &&
          MediaUploadLimits.detectImageContentType(bytes) == null) {
        throw const PostServiceException(
          'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
        );
      }
    }
  }

  Future<void> updateAuthorProfile(AuthUser author) async {
    final posts = await restorePosts();
    final updatedPosts = posts
        .map(
          (post) => post.isOwn || post.username == author.username
              ? _postWithAuthor(post, author)
              : post,
        )
        .toList();
    await _savePosts(updatedPosts);
    revision.value++;
  }

  Future<void> deletePost(String id) async {
    final posts = await restorePosts();
    posts.removeWhere((post) => post.id == id && post.isOwn);
    await _savePosts(posts);
    revision.value++;
  }

  Future<Set<String>> restoreLikedPostIds() => _restoreIdSet(_likedPostsKey);

  Future<Set<String>> restoreSavedPostIds() => _restoreIdSet(_savedPostsKey);

  Future<void> setPostLiked(String postId, bool liked) async {
    final ids = await restoreLikedPostIds();
    if (liked) {
      ids.add(postId);
    } else {
      ids.remove(postId);
    }
    await _saveIdSet(_likedPostsKey, ids);
  }

  Future<void> setPostSaved(String postId, bool saved) async {
    final ids = await restoreSavedPostIds();
    if (saved) {
      ids.add(postId);
    } else {
      ids.remove(postId);
    }
    await _saveIdSet(_savedPostsKey, ids);
  }

  Future<List<PostComment>> restoreComments(String postId) async {
    final comments = await _restoreCommentsByPost();
    return comments[postId] ?? const [];
  }

  Future<PostComment> addComment({
    required AuthUser author,
    required String postId,
    required String body,
    String parentId = '',
  }) async {
    final cleaned = body.trim();
    if (cleaned.isEmpty) {
      throw const PostServiceException('Escribí un comentario primero.');
    }
    if (cleaned.length > maxCommentLength) {
      throw const PostServiceException('El comentario es demasiado largo.');
    }
    final comment = PostComment(
      id: 'local-comment-${DateTime.now().microsecondsSinceEpoch}',
      parentId: parentId,
      author: author.name,
      username: author.username,
      avatarAsset: author.avatarAsset,
      body: cleaned,
      time: 'Ahora',
      isOwn: true,
    );
    final comments = await _restoreCommentsByPost();
    final postComments = [...(comments[postId] ?? const <PostComment>[])];
    comments[postId] = parentId.isEmpty
        ? [...postComments, comment]
        : _appendReply(postComments, parentId, comment);
    await _saveCommentsByPost(comments);
    await _updatePostCommentCount(postId, 1);
    revision.value++;
    return comment;
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final comments = await _restoreCommentsByPost();
    final postComments = comments[postId] ?? const <PostComment>[];
    final removedCount =
        _countCommentTree(postComments) -
        _countCommentTree(_removeComment(postComments, commentId));
    if (removedCount <= 0) return;
    comments[postId] = _removeComment(postComments, commentId);
    await _saveCommentsByPost(comments);
    await _updatePostCommentCount(postId, -removedCount);
    revision.value++;
  }

  Future<void> _savePosts(List<HubPost> posts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _postsKey,
      jsonEncode(posts.take(_maxPosts).map(_postToJson).toList()),
    );
  }

  HubPost _postFromJson(Map<String, dynamic> json) {
    final imageBytes = json['imageBytes'] as String?;
    return HubPost(
      id: json['id'] as String,
      authorId: json['authorId'] as String? ?? 'local-user',
      author: json['author'] as String,
      username: json['username'] as String,
      avatarAsset: json['avatarAsset'] as String,
      imageAsset:
          json['imageAsset'] as String? ?? 'assets/demo-posts/post-02.jpg',
      imageBytes: imageBytes == null ? null : base64Decode(imageBytes),
      mediaPath: json['mediaPath'] as String? ?? '',
      containsVideo: json['containsVideo'] as bool? ?? false,
      videoTrimStartSeconds:
          (json['videoTrimStartSeconds'] as num?)?.toDouble() ?? 0,
      videoTrimEndSeconds: (json['videoTrimEndSeconds'] as num?)?.toDouble(),
      videoMuted: json['videoMuted'] as bool? ?? true,
      mediaItems: (json['mediaItems'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_mediaItemFromJson)
          .toList(),
      elements: (json['elements'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_elementFromJson)
          .toList(),
      mediaScale: (json['mediaScale'] as num?)?.toDouble() ?? 1,
      mediaOffset: _offsetFromJson(json['mediaOffset']),
      mediaRotation: (json['mediaRotation'] as num?)?.toDouble() ?? 0,
      music: json['music'] as String? ?? '',
      musicAsset: json['musicAsset'] as String? ?? '',
      filterIndex: json['filterIndex'] as int? ?? 0,
      taggedPeople: (json['taggedPeople'] as List<dynamic>? ?? const [])
          .cast<String>(),
      taggedUserIds: (json['taggedUserIds'] as List<dynamic>? ?? const [])
          .cast<String>(),
      artist: json['artist'] as String? ?? '',
      privacy: json['privacy'] as String? ?? 'Todos',
      caption: json['caption'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      likes: json['likes'] as String? ?? '0',
      comments: json['comments'] as String? ?? '0',
      mood: json['mood'] as String? ?? 'Nuevo',
      time: json['time'] as String? ?? 'Ahora',
      shares: json['shares'] as String? ?? '0',
      saves: json['saves'] as String? ?? '0',
      location: json['location'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      isOwn: true,
      likedByCurrentUser: json['likedByCurrentUser'] as bool? ?? false,
      savedByCurrentUser: json['savedByCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _postToJson(HubPost post) {
    return {
      'id': post.id,
      'authorId': post.authorId,
      'author': post.author,
      'username': post.username,
      'avatarAsset': post.avatarAsset,
      'imageAsset': post.imageAsset,
      if (post.imageBytes != null && !post.containsVideo)
        'imageBytes': base64Encode(post.imageBytes!),
      'mediaPath': post.mediaPath,
      'containsVideo': post.containsVideo,
      'videoTrimStartSeconds': post.videoTrimStartSeconds,
      'videoTrimEndSeconds': post.videoTrimEndSeconds,
      'videoMuted': post.videoMuted,
      'mediaItems': post.effectiveMediaItems.map(_mediaItemToJson).toList(),
      'elements': post.elements.map(_elementToJson).toList(),
      'mediaScale': post.mediaScale,
      'mediaOffset': _offsetToJson(post.mediaOffset),
      'mediaRotation': post.mediaRotation,
      'music': post.music,
      'musicAsset': post.musicAsset,
      'filterIndex': post.filterIndex,
      'taggedPeople': post.taggedPeople,
      'taggedUserIds': post.taggedUserIds,
      'artist': post.artist,
      'privacy': post.privacy,
      'caption': post.caption,
      'tags': post.tags,
      'likes': post.likes,
      'comments': post.comments,
      'mood': post.mood,
      'time': post.time,
      'shares': post.shares,
      'saves': post.saves,
      'location': post.location,
      if (post.createdAt != null)
        'createdAt': post.createdAt!.toIso8601String(),
      'likedByCurrentUser': post.likedByCurrentUser,
      'savedByCurrentUser': post.savedByCurrentUser,
    };
  }

  HubPost _postWithAuthor(HubPost post, AuthUser author) {
    return HubPost(
      id: post.id,
      authorId: post.authorId,
      author: author.name,
      username: author.username,
      avatarAsset: author.avatarAsset,
      imageAsset: post.imageAsset,
      imageBytes: post.imageBytes,
      mediaPath: post.mediaPath,
      containsVideo: post.containsVideo,
      videoTrimStartSeconds: post.videoTrimStartSeconds,
      videoTrimEndSeconds: post.videoTrimEndSeconds,
      videoMuted: post.videoMuted,
      mediaItems: post.effectiveMediaItems,
      elements: post.elements,
      mediaScale: post.mediaScale,
      mediaOffset: post.mediaOffset,
      mediaRotation: post.mediaRotation,
      music: post.music,
      musicAsset: post.musicAsset,
      filterIndex: post.filterIndex,
      taggedPeople: post.taggedPeople,
      artist: post.artist,
      privacy: post.privacy,
      caption: post.caption,
      tags: post.tags,
      likes: post.likes,
      comments: post.comments,
      mood: post.mood,
      time: post.time,
      shares: post.shares,
      saves: post.saves,
      location: post.location,
      createdAt: post.createdAt,
      isOwn: post.isOwn,
      likedByCurrentUser: post.likedByCurrentUser,
      savedByCurrentUser: post.savedByCurrentUser,
    );
  }

  Future<Set<String>> _restoreIdSet(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(key);
    if (stored == null) return {};
    try {
      return (jsonDecode(stored) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      await preferences.remove(key);
      return {};
    }
  }

  Future<void> _saveIdSet(String key, Set<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(ids.toList()));
  }

  PostMediaItem _mediaItemFromJson(Map<String, dynamic> json) {
    final imageBytes = json['imageBytes'] as String?;
    return PostMediaItem(
      id:
          json['id'] as String? ??
          'media-${DateTime.now().microsecondsSinceEpoch}',
      type: PostMediaType.values.byName(
        json['type'] as String? ?? PostMediaType.image.name,
      ),
      imageAsset: json['imageAsset'] as String? ?? '',
      imageBytes: imageBytes == null ? null : base64Decode(imageBytes),
      mediaPath: json['mediaPath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      mediaScale: (json['mediaScale'] as num?)?.toDouble() ?? 1,
      mediaOffset: _offsetFromJson(json['mediaOffset']),
      mediaRotation: (json['mediaRotation'] as num?)?.toDouble() ?? 0,
      videoTrimStartSeconds:
          (json['videoTrimStartSeconds'] as num?)?.toDouble() ?? 0,
      videoTrimEndSeconds: (json['videoTrimEndSeconds'] as num?)?.toDouble(),
      videoMuted: json['videoMuted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _mediaItemToJson(PostMediaItem item) {
    return {
      'id': item.id,
      'type': item.type.name,
      'imageAsset': item.imageAsset,
      if (item.imageBytes != null && !item.isVideo)
        'imageBytes': base64Encode(item.imageBytes!),
      'mediaPath': item.mediaPath,
      'fileName': item.fileName,
      'mimeType': item.mimeType,
      'fileSizeBytes': item.fileSizeBytes,
      'mediaScale': item.mediaScale,
      'mediaOffset': _offsetToJson(item.mediaOffset),
      'mediaRotation': item.mediaRotation,
      'videoTrimStartSeconds': item.videoTrimStartSeconds,
      'videoTrimEndSeconds': item.videoTrimEndSeconds,
      'videoMuted': item.videoMuted,
    };
  }

  StoryElement _elementFromJson(Map<String, dynamic> json) {
    final imageBytes = json['imageBytes'] as String?;
    return StoryElement(
      id: json['id'] as String,
      type: StoryElementType.values.byName(json['type'] as String),
      content: json['content'] as String,
      position: _offsetFromJson(json['position']),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
      backgroundColor: json['backgroundColor'] == null
          ? null
          : Color(json['backgroundColor'] as int),
      imageBytes: imageBytes == null ? null : base64Decode(imageBytes),
    );
  }

  Map<String, dynamic> _elementToJson(StoryElement element) {
    return {
      'id': element.id,
      'type': element.type.name,
      'content': element.content,
      'position': _offsetToJson(element.position),
      'scale': element.scale,
      'rotation': element.rotation,
      'color': element.color.toARGB32(),
      if (element.backgroundColor != null)
        'backgroundColor': element.backgroundColor!.toARGB32(),
      if (element.imageBytes != null)
        'imageBytes': base64Encode(element.imageBytes!),
    };
  }

  Offset _offsetFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return Offset.zero;
    return Offset(
      (json['dx'] as num?)?.toDouble() ?? 0,
      (json['dy'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> _offsetToJson(Offset offset) {
    return {'dx': offset.dx, 'dy': offset.dy};
  }

  Future<Map<String, List<PostComment>>> _restoreCommentsByPost() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_commentsKey);
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      return decoded.map(
        (postId, value) => MapEntry(
          postId,
          (value as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(_commentFromJson)
              .toList(),
        ),
      );
    } catch (_) {
      await preferences.remove(_commentsKey);
      return {};
    }
  }

  Future<void> _saveCommentsByPost(
    Map<String, List<PostComment>> comments,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _commentsKey,
      jsonEncode(
        comments.map(
          (postId, value) => MapEntry(
            postId,
            value.map(_commentToJson).toList(growable: false),
          ),
        ),
      ),
    );
  }

  PostComment _commentFromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      author: json['author'] as String? ?? 'Fan Hallyu',
      username: json['username'] as String? ?? '@fan',
      avatarAsset:
          json['avatarAsset'] as String? ?? 'assets/demo-users/user-01.jpg',
      body: json['body'] as String? ?? '',
      time: json['time'] as String? ?? 'Ahora',
      likes: json['likes'] as int? ?? 0,
      replies: (json['replies'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_commentFromJson)
          .toList(),
      isOwn: json['isOwn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _commentToJson(PostComment comment) {
    return {
      'id': comment.id,
      'parentId': comment.parentId,
      'authorId': comment.authorId,
      'author': comment.author,
      'username': comment.username,
      'avatarAsset': comment.avatarAsset,
      'body': comment.body,
      'time': comment.time,
      'likes': comment.likes,
      'replies': comment.replies.map(_commentToJson).toList(growable: false),
      'isOwn': comment.isOwn,
    };
  }

  List<PostComment> _appendReply(
    List<PostComment> comments,
    String parentId,
    PostComment reply,
  ) {
    return [
      for (final comment in comments)
        if (comment.id == parentId)
          comment.copyWith(replies: [...comment.replies, reply])
        else
          comment.copyWith(
            replies: _appendReply(comment.replies, parentId, reply),
          ),
    ];
  }

  List<PostComment> _removeComment(
    List<PostComment> comments,
    String commentId,
  ) {
    return [
      for (final comment in comments)
        if (comment.id != commentId)
          comment.copyWith(replies: _removeComment(comment.replies, commentId)),
    ];
  }

  int _countCommentTree(List<PostComment> comments) {
    var total = 0;
    for (final comment in comments) {
      total += 1 + _countCommentTree(comment.replies);
    }
    return total;
  }

  Future<void> _updatePostCommentCount(String postId, int delta) async {
    final posts = await restorePosts();
    final updated = posts.map((post) {
      if (post.id != postId) return post;
      final nextCount = _parseCount(post.comments) + delta;
      return _postWithCounts(post, comments: nextCount.clamp(0, 999999));
    }).toList();
    await _savePosts(updated);
  }

  int _parseCount(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  HubPost _postWithCounts(HubPost post, {int? comments}) {
    return HubPost(
      id: post.id,
      authorId: post.authorId,
      author: post.author,
      username: post.username,
      avatarAsset: post.avatarAsset,
      imageAsset: post.imageAsset,
      imageBytes: post.imageBytes,
      mediaPath: post.mediaPath,
      containsVideo: post.containsVideo,
      videoTrimStartSeconds: post.videoTrimStartSeconds,
      videoTrimEndSeconds: post.videoTrimEndSeconds,
      videoMuted: post.videoMuted,
      mediaItems: post.effectiveMediaItems,
      elements: post.elements,
      mediaScale: post.mediaScale,
      mediaOffset: post.mediaOffset,
      mediaRotation: post.mediaRotation,
      music: post.music,
      musicAsset: post.musicAsset,
      filterIndex: post.filterIndex,
      taggedPeople: post.taggedPeople,
      artist: post.artist,
      privacy: post.privacy,
      caption: post.caption,
      tags: post.tags,
      likes: post.likes,
      comments: '${comments ?? _parseCount(post.comments)}',
      mood: post.mood,
      time: post.time,
      shares: post.shares,
      saves: post.saves,
      location: post.location,
      createdAt: post.createdAt,
      isOwn: post.isOwn,
      likedByCurrentUser: post.likedByCurrentUser,
      savedByCurrentUser: post.savedByCurrentUser,
    );
  }
}

class PostServiceException implements Exception {
  const PostServiceException(this.message);

  final String message;

  @override
  String toString() => 'PostServiceException: $message';
}
