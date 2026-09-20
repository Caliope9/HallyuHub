import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'media_upload_limits.dart';

enum DropFeedMode { forYou, viral, following }

class LocalDropService {
  const LocalDropService();

  static const _dropsKey = 'hallyuhub.local-drops.v1';
  static const _likedDropsKey = 'hallyuhub.local-drop-likes.v1';
  static const _savedDropsKey = 'hallyuhub.local-drop-saves.v1';
  static const _dropCommentsKey = 'hallyuhub.local-drop-comments.v1';
  static const _maxDrops = 80;
  static const maxCommentLength = 1000;
  static const maxVideoBytes = MediaUploadLimits.dropVideoBytes;
  static const maxVideoDurationSeconds =
      MediaUploadLimits.dropVideoDurationSeconds;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealDrops => false;

  Future<void> recordView({
    required String dropId,
    required String playbackSessionId,
  }) async {}

  Future<List<DropClip>> restoreDrops({
    int limit = _maxDrops,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    DropFeedMode feedMode = DropFeedMode.forYou,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_dropsKey);
    if (stored == null) return [];
    try {
      final drops = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .toList();
      final filtered = onlyCurrentUser
          ? drops.where((drop) => drop.isOwn).toList()
          : authorId == null || authorId.isEmpty
          ? drops
          : drops.where((drop) => drop.creatorId == authorId).toList();
      return filtered.skip(offset).take(limit).toList(growable: false);
    } catch (_) {
      await preferences.remove(_dropsKey);
      return [];
    }
  }

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
    final now = DateTime.now();
    final drop = DropClip(
      id: 'local-drop-${now.microsecondsSinceEpoch}',
      title: caption.isEmpty ? 'Nuevo drop' : caption,
      artist: artist.isEmpty ? 'Artista etiquetado' : artist,
      creator: author.username,
      creatorId: author.username,
      creatorName: author.name,
      creatorAvatarAsset: author.avatarAsset,
      audio: audio,
      imageAsset: 'assets/demo-posts/post-08.jpg',
      views: '0',
      likes: '0',
      comments: '0',
      groupId: groupId,
      artistId: artistId,
      caption: caption,
      location: location,
      videoPath: videoPath,
      videoDurationSeconds: videoDurationSeconds,
      videoTrimStartSeconds: videoTrimStartSeconds,
      videoTrimEndSeconds: videoTrimEndSeconds,
      optimizedForUpload: optimizedForUpload,
      filter: filter,
      createdAt: now,
      isOwn: true,
    );
    final local = await restoreDrops();
    local.insert(0, drop);
    await _save(local);
    revision.value++;
    return drop;
  }

  Future<void> deleteDrop(String id) async {
    final local = await restoreDrops();
    local.removeWhere((drop) => drop.id == id);
    await _save(local);
    revision.value++;
  }

  Future<Set<String>> restoreLikedDropIds() async =>
      _restoreIdSet(_likedDropsKey);

  Future<Set<String>> restoreSavedDropIds() async =>
      _restoreIdSet(_savedDropsKey);

  Future<void> setDropLiked(String dropId, bool liked) async {
    await _setIdEnabled(_likedDropsKey, dropId, liked);
    revision.value++;
  }

  Future<void> setDropSaved(String dropId, bool saved) async {
    await _setIdEnabled(_savedDropsKey, dropId, saved);
    revision.value++;
  }

  Future<List<PostComment>> restoreComments(String dropId) async {
    final rows = await _restoreCommentRows();
    final comments = rows
        .where((row) => row['dropId'] == dropId)
        .toList(growable: false);
    return _commentsFromRows(comments);
  }

  Future<PostComment> addComment({
    required AuthUser author,
    required String dropId,
    required String body,
    String parentId = '',
  }) async {
    final cleaned = body.trim();
    if (cleaned.isEmpty) {
      throw const DropServiceException('Escribí un comentario primero.');
    }
    if (cleaned.length > maxCommentLength) {
      throw const DropServiceException('El comentario es demasiado largo.');
    }
    final row = {
      'id': 'local-drop-comment-${DateTime.now().microsecondsSinceEpoch}',
      'dropId': dropId,
      'parentId': parentId,
      'authorId': author.username,
      'author': author.name,
      'username': author.username,
      'avatarAsset': author.avatarAsset,
      'body': cleaned,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final rows = await _restoreCommentRows();
    rows.add(row);
    await _saveCommentRows(rows);
    revision.value++;
    return _commentFromRow(row);
  }

  Future<void> deleteComment({
    required String dropId,
    required String commentId,
  }) async {
    final rows = await _restoreCommentRows();
    final removeIds = <String>{commentId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final row in rows) {
        final id = row['id'] as String? ?? '';
        final parentId = row['parentId'] as String? ?? '';
        if (id.isNotEmpty &&
            removeIds.contains(parentId) &&
            removeIds.add(id)) {
          changed = true;
        }
      }
    }
    rows.removeWhere(
      (row) => row['dropId'] == dropId && removeIds.contains(row['id']),
    );
    await _saveCommentRows(rows);
    revision.value++;
  }

  Future<void> _save(List<DropClip> drops) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _dropsKey,
      jsonEncode(drops.take(_maxDrops).map(_toJson).toList()),
    );
  }

  DropClip _fromJson(Map<String, dynamic> json) {
    return DropClip(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Nuevo drop',
      artist: json['artist'] as String? ?? 'Artista etiquetado',
      creator: json['creator'] as String? ?? '@hallyu.fan',
      audio: json['audio'] as String? ?? 'Audio original',
      imageAsset:
          json['imageAsset'] as String? ?? 'assets/demo-posts/post-08.jpg',
      views: json['views'] as String? ?? '0',
      likes: json['likes'] as String? ?? '0',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      creatorAvatarAsset: json['creatorAvatarAsset'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      artistId: json['artistId'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      location: json['location'] as String? ?? '',
      videoPath: json['videoPath'] as String? ?? '',
      videoDurationSeconds: (json['videoDurationSeconds'] as num?)?.toDouble(),
      videoTrimStartSeconds:
          (json['videoTrimStartSeconds'] as num?)?.toDouble() ?? 0,
      videoTrimEndSeconds: (json['videoTrimEndSeconds'] as num?)?.toDouble(),
      optimizedForUpload: json['optimizedForUpload'] as bool? ?? false,
      filter: json['filter'] as String? ?? 'Original',
      comments: json['comments'] as String? ?? '0',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      isOwn: json['isOwn'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toJson(DropClip drop) {
    return {
      'id': drop.id,
      'title': drop.title,
      'artist': drop.artist,
      'creator': drop.creator,
      'audio': drop.audio,
      'imageAsset': drop.imageAsset,
      'views': drop.views,
      'likes': drop.likes,
      'viewCount': drop.viewCount,
      'creatorId': drop.creatorId,
      'creatorName': drop.creatorName,
      'creatorAvatarAsset': drop.creatorAvatarAsset,
      'groupId': drop.groupId,
      'artistId': drop.artistId,
      'caption': drop.caption,
      'location': drop.location,
      'videoPath': drop.videoPath,
      'videoDurationSeconds': drop.videoDurationSeconds,
      'videoTrimStartSeconds': drop.videoTrimStartSeconds,
      'videoTrimEndSeconds': drop.videoTrimEndSeconds,
      'optimizedForUpload': drop.optimizedForUpload,
      'filter': drop.filter,
      'comments': drop.comments,
      if (drop.createdAt != null)
        'createdAt': drop.createdAt!.toIso8601String(),
      'isOwn': drop.isOwn,
    };
  }

  Future<Set<String>> _restoreIdSet(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(key);
    return stored == null ? <String>{} : stored.toSet();
  }

  Future<void> _setIdEnabled(String key, String id, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = (preferences.getStringList(key) ?? const <String>[]).toSet();
    if (enabled) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await preferences.setStringList(key, ids.toList(growable: false));
  }

  Future<List<Map<String, dynamic>>> _restoreCommentRows() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_dropCommentsKey);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      await preferences.remove(_dropCommentsKey);
      return [];
    }
  }

  Future<void> _saveCommentRows(List<Map<String, dynamic>> rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_dropCommentsKey, jsonEncode(rows));
  }

  List<PostComment> _commentsFromRows(List<Map<String, dynamic>> rows) {
    final rowsByParent = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final parentId = row['parentId'] as String? ?? '';
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

  PostComment _commentFromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.tryParse(row['createdAt'] as String? ?? '');
    return PostComment(
      id: row['id'] as String? ?? '',
      parentId: row['parentId'] as String? ?? '',
      authorId: row['authorId'] as String? ?? '',
      author: row['author'] as String? ?? 'Fan Hallyu',
      username: row['username'] as String? ?? '@fan',
      avatarAsset:
          row['avatarAsset'] as String? ?? 'assets/demo-users/user-01.jpg',
      body: row['body'] as String? ?? '',
      time: _relativeTime(createdAt),
      isOwn: true,
    );
  }

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Ahora';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }
}

class DropServiceException implements Exception {
  const DropServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
