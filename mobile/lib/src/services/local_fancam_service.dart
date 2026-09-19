import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'media_upload_limits.dart';

enum FancamFeedMode { forYou, viral, following }

class LocalFancamService {
  const LocalFancamService();

  static const _fancamsKey = 'hallyuhub.local-fancams.v1';
  static const _likedFancamsKey = 'hallyuhub.local-fancam-likes.v1';
  static const _savedFancamsKey = 'hallyuhub.local-fancam-saves.v1';
  static const _fancamCommentsKey = 'hallyuhub.local-fancam-comments.v1';
  static const _maxFancams = 80;
  static const maxCommentLength = 1000;
  static const maxVideoBytes = MediaUploadLimits.fancamVideoBytes;
  static const maxVideoDurationSeconds =
      MediaUploadLimits.fancamVideoDurationSeconds;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealFancams => false;

  Future<void> recordView({
    required String fancamId,
    required String playbackSessionId,
  }) async {}

  Future<List<Fancam>> restoreFancams({
    int limit = _maxFancams,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    FancamFeedMode feedMode = FancamFeedMode.forYou,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_fancamsKey);
    if (stored == null) return [];
    try {
      final fancams = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .toList();
      final filtered = onlyCurrentUser
          ? fancams.where((fancam) => fancam.isOwn).toList()
          : authorId == null || authorId.isEmpty
          ? fancams
          : fancams.where((fancam) => fancam.creatorId == authorId).toList();
      return filtered.skip(offset).take(limit).toList(growable: false);
    } catch (_) {
      await preferences.remove(_fancamsKey);
      return [];
    }
  }

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
    final now = DateTime.now();
    final fancam = Fancam(
      id: 'local-fancam-${now.microsecondsSinceEpoch}',
      title: caption.isEmpty ? 'Nueva fancam' : caption,
      artist: artist.isEmpty ? 'Artista etiquetado' : artist,
      creator: author.username,
      creatorId: author.username,
      creatorName: author.name,
      creatorAvatarAsset: author.avatarAsset,
      imageAsset: 'assets/demo-posts/post-03.jpg',
      videoPath: videoPath,
      duration: duration,
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
      createdAt: now,
      isOwn: true,
    );
    final local = await restoreFancams();
    local.insert(0, fancam);
    await _save(local);
    revision.value++;
    return fancam;
  }

  Future<void> deleteFancam(String id) async {
    final local = await restoreFancams();
    local.removeWhere((fancam) => fancam.id == id);
    await _save(local);
    revision.value++;
  }

  Future<Set<String>> restoreLikedFancamIds() async =>
      _restoreIdSet(_likedFancamsKey);

  Future<Set<String>> restoreSavedFancamIds() async =>
      _restoreIdSet(_savedFancamsKey);

  Future<void> setFancamLiked(String fancamId, bool liked) async {
    await _setIdEnabled(_likedFancamsKey, fancamId, liked);
    revision.value++;
  }

  Future<void> setFancamSaved(String fancamId, bool saved) async {
    await _setIdEnabled(_savedFancamsKey, fancamId, saved);
    revision.value++;
  }

  Future<List<PostComment>> restoreComments(String fancamId) async {
    final rows = await _restoreCommentRows();
    final comments = rows
        .where((row) => row['fancamId'] == fancamId)
        .toList(growable: false);
    return _commentsFromRows(comments);
  }

  Future<PostComment> addComment({
    required AuthUser author,
    required String fancamId,
    required String body,
    String parentId = '',
  }) async {
    final cleaned = body.trim();
    if (cleaned.isEmpty) {
      throw const FancamServiceException('Escribí un comentario primero.');
    }
    if (cleaned.length > maxCommentLength) {
      throw const FancamServiceException('El comentario es demasiado largo.');
    }
    final row = {
      'id': 'local-fancam-comment-${DateTime.now().microsecondsSinceEpoch}',
      'fancamId': fancamId,
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
    required String fancamId,
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
      (row) => row['fancamId'] == fancamId && removeIds.contains(row['id']),
    );
    await _saveCommentRows(rows);
    revision.value++;
  }

  Future<void> _save(List<Fancam> fancams) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _fancamsKey,
      jsonEncode(fancams.take(_maxFancams).map(_toJson).toList()),
    );
  }

  Fancam _fromJson(Map<String, dynamic> json) {
    return Fancam(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Nueva fancam',
      artist: json['artist'] as String? ?? 'Artista etiquetado',
      creator: json['creator'] as String? ?? '@hallyu.fan',
      imageAsset:
          json['imageAsset'] as String? ?? 'assets/demo-posts/post-03.jpg',
      duration: json['duration'] as String? ?? '00:30',
      energy: json['energy'] as String? ?? 'Nuevo',
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      creatorAvatarAsset: json['creatorAvatarAsset'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      artistId: json['artistId'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      audio: json['audio'] as String? ?? '',
      location: json['location'] as String? ?? '',
      videoPath: json['videoPath'] as String? ?? '',
      likes: json['likes'] as String? ?? '0',
      comments: json['comments'] as String? ?? '0',
      saves: json['saves'] as String? ?? '0',
      shares: json['shares'] as String? ?? '0',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      repostedByUserId: json['repostedByUserId'] as String? ?? '',
      repostedByUsername: json['repostedByUsername'] as String? ?? '',
      repostedAt: json['repostedAt'] == null
          ? null
          : DateTime.tryParse(json['repostedAt'] as String),
      isOwn: json['isOwn'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toJson(Fancam fancam) {
    return {
      'id': fancam.id,
      'title': fancam.title,
      'artist': fancam.artist,
      'creator': fancam.creator,
      'imageAsset': fancam.imageAsset,
      'duration': fancam.duration,
      'energy': fancam.energy,
      'creatorId': fancam.creatorId,
      'creatorName': fancam.creatorName,
      'creatorAvatarAsset': fancam.creatorAvatarAsset,
      'groupId': fancam.groupId,
      'artistId': fancam.artistId,
      'caption': fancam.caption,
      'audio': fancam.audio,
      'location': fancam.location,
      'videoPath': fancam.videoPath,
      'likes': fancam.likes,
      'comments': fancam.comments,
      'saves': fancam.saves,
      'shares': fancam.shares,
      'viewCount': fancam.viewCount,
      if (fancam.createdAt != null)
        'createdAt': fancam.createdAt!.toIso8601String(),
      'repostedByUserId': fancam.repostedByUserId,
      'repostedByUsername': fancam.repostedByUsername,
      if (fancam.repostedAt != null)
        'repostedAt': fancam.repostedAt!.toIso8601String(),
      'isOwn': fancam.isOwn,
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
    final stored = preferences.getString(_fancamCommentsKey);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      await preferences.remove(_fancamCommentsKey);
      return [];
    }
  }

  Future<void> _saveCommentRows(List<Map<String, dynamic>> rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_fancamCommentsKey, jsonEncode(rows));
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

class FancamServiceException implements Exception {
  const FancamServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
