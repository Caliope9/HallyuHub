import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_story_service.dart';
import 'media_upload_limits.dart';

class SupabaseStoryService extends LocalStoryService {
  SupabaseStoryService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;
  static const _maxImageBytes = MediaUploadLimits.imageBytes;
  static const _maxVideoBytes = MediaUploadLimits.storyVideoBytes;
  static const _storyLifetime = Duration(hours: 24);

  @override
  bool get usesRealStories => true;

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<Story>> restoreOwnStories() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];
    final rows = await _client
        .from('stories')
        .select(_storySelect)
        .eq('author_id', currentUserId)
        .filter('deleted_at', 'is', null)
        .gt('expires_at', _nowIso())
        .order('created_at', ascending: false)
        .limit(40);
    return _storiesFromRows(rows.cast<Map<String, dynamic>>());
  }

  @override
  Future<List<Story>> restoreFollowingStories({
    Set<String> followingIds = const {},
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || followingIds.isEmpty) return [];
    final rows = await _client
        .from('stories')
        .select(_storySelect)
        .inFilter('author_id', followingIds.toList())
        .filter('deleted_at', 'is', null)
        .gt('expires_at', _nowIso())
        .order('created_at', ascending: false)
        .limit(80);
    return _storiesFromRows(rows.cast<Map<String, dynamic>>());
  }

  @override
  Future<Story> publish({
    required AuthUser author,
    required StoryDraft draft,
    Iterable<Story>? currentStories,
    List<StoryViewer> viewers = const [],
    int views = 0,
    int stars = 0,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const StoryServiceException(
        'Necesitás iniciar sesión para publicar una historia.',
      );
    }
    if (draft.type == StoryContentType.video &&
        _videoDuration(draft) > MediaUploadLimits.storyVideoDurationSeconds) {
      throw const StoryServiceException(
        'Las historias de video pueden durar hasta 60 segundos durante el acceso anticipado.',
      );
    }

    final insertedStory = await _client
        .from('stories')
        .insert({
          'author_id': authUser.id,
          'title': draft.title,
          'detail': draft.detail,
          'text': draft.text,
          'music': draft.music,
          'music_asset': draft.musicAsset,
          'content_type': draft.type.name,
          'duration_seconds': _durationForDraft(draft),
          'visual_filter': draft.visualFilter.name,
          'background_colors': draft.backgroundColors
              .map((color) => color.toARGB32())
              .toList(),
          'elements': draft.elements.map(_elementToJson).toList(),
          'media_transform': _transformFor(draft),
          'audience_type': draft.audienceType.storageValue,
          if (draft.sharedContentType.isNotEmpty)
            'shared_content_type': draft.sharedContentType,
          if (draft.sharedContentId.isNotEmpty)
            'shared_content_id': draft.sharedContentId,
          'expires_at': DateTime.now()
              .toUtc()
              .add(_storyLifetime)
              .toIso8601String(),
        })
        .select('id,created_at')
        .single();

    final storyId = insertedStory['id'] as String;
    _StoredStoryMedia? storedMedia;
    try {
      await _storeAudience(authUser.id, storyId, draft);
      storedMedia = await _storeMedia(authUser.id, storyId, draft);
      if (storedMedia != null) {
        await _client.from('story_media').insert({
          'story_id': storyId,
          'media_type': draft.type == StoryContentType.video
              ? 'video'
              : 'image',
          'storage_bucket': storedMedia.bucket,
          'storage_path': storedMedia.path,
          'public_url': storedMedia.publicUrl,
          'sort_order': 0,
          'transform': _transformFor(draft, stored: storedMedia),
        });
      }
    } catch (error) {
      await _cleanupFailedPublish(authUser.id, storyId, storedMedia);
      if (error is StoryServiceException) rethrow;
      throw const StoryServiceException(
        'No pudimos subir la historia. Revisá conexión e intentá otra vez.',
      );
    }

    LocalStoryService.revision.value++;
    final publicUrl = storedMedia?.publicUrl ?? draft.imageAsset;
    return Story(
      id: storyId,
      authorId: authUser.id,
      name: author.name,
      fandom: author.fandom,
      avatarAsset: author.avatarAsset,
      imageAsset: draft.type == StoryContentType.text ? '' : publicUrl,
      mediaPath: draft.type == StoryContentType.video ? publicUrl : '',
      title: draft.title,
      detail: draft.detail,
      music: draft.music,
      musicAsset: draft.musicAsset,
      text: draft.text,
      elements: draft.elements,
      mediaScale: draft.mediaScale,
      mediaOffset: draft.mediaOffset,
      mediaRotation: draft.mediaRotation,
      videoTrimStartSeconds: draft.videoTrimStartSeconds,
      videoTrimEndSeconds: draft.videoTrimEndSeconds,
      videoMuted: draft.videoMuted,
      durationSeconds: _durationForDraft(draft),
      contentType: draft.type,
      backgroundColors: draft.backgroundColors,
      visualFilter: draft.visualFilter,
      viewers: const [],
      views: 0,
      stars: 0,
      createdAt: DateTime.tryParse(
        insertedStory['created_at'] as String? ?? '',
      ),
      taggedPeople: draft.taggedPeople,
      taggedUserIds: draft.taggedUserIds,
      audienceType: draft.audienceType,
      audienceUserIds: draft.audienceUserIds,
      sharedContentType: draft.sharedContentType,
      sharedContentId: draft.sharedContentId,
      isOwn: true,
    );
  }

  Future<void> _storeAudience(
    String ownerId,
    String storyId,
    StoryDraft draft,
  ) async {
    if (draft.audienceType == StoryAudienceType.include &&
        draft.audienceUserIds.isEmpty) {
      throw const StoryServiceException(
        'Elegí al menos una persona para compartir esta historia.',
      );
    }
    if (draft.audienceType == StoryAudienceType.closeFriends) {
      if (draft.audienceUserIds.isEmpty) {
        throw const StoryServiceException(
          'Elegí al menos una persona para Mejores amigos.',
        );
      }
      await _client.from('close_friends').upsert(
        draft.audienceUserIds
            .where((id) => id.isNotEmpty && id != ownerId)
            .map(
              (friendId) => {
                'owner_id': ownerId,
                'friend_id': friendId,
              },
            )
            .toList(growable: false),
        onConflict: 'owner_id,friend_id',
      );
      return;
    }
    if (draft.audienceType == StoryAudienceType.include ||
        draft.audienceType == StoryAudienceType.exclude) {
      await _client.from('story_audience_users').insert(
        draft.audienceUserIds
            .where((id) => id.isNotEmpty && id != ownerId)
            .map(
              (userId) => {
                'story_id': storyId,
                'user_id': userId,
              },
            )
            .toList(growable: false),
      );
    }
  }

  @override
  Future<void> updateOwnStoryProfile(AuthUser author) async {
    LocalStoryService.revision.value++;
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw const StoryServiceException('Necesitás iniciar sesión.');
    }
    try {
      await _client.rpc('delete_my_story', params: {'p_story_id': storyId});
    } catch (_) {
      await _client
          .from('stories')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'expires_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', storyId)
          .eq('author_id', currentUserId);
    }
    LocalStoryService.revision.value++;
  }

  @override
  Future<Set<String>> restoreViewedStoryIds() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return {};
    final rows = await _client
        .from('story_views')
        .select('story_id')
        .eq('viewer_id', currentUserId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['story_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  @override
  Future<void> saveViewedStoryIds(Set<String> ids) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || ids.isEmpty) return;
    for (final storyId in ids) {
      await _client.from('story_views').upsert({
        'story_id': storyId,
        'viewer_id': currentUserId,
        'viewed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'story_id,viewer_id');
    }
  }

  @override
  Future<Set<String>> restoreStarredStoryIds() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return {};
    final rows = await _client
        .from('story_likes')
        .select('story_id')
        .eq('user_id', currentUserId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['story_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  @override
  Future<void> saveStarredStoryIds(Set<String> ids) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    final existing = await restoreStarredStoryIds();
    final additions = ids.difference(existing);
    final removals = existing.difference(ids);
    for (final storyId in additions) {
      await _client.from('story_likes').upsert({
        'story_id': storyId,
        'user_id': currentUserId,
      }, onConflict: 'story_id,user_id');
    }
    for (final storyId in removals) {
      await _client
          .from('story_likes')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', currentUserId);
    }
    if (additions.isNotEmpty || removals.isNotEmpty) {
      LocalStoryService.revision.value++;
    }
  }

  Future<List<Story>> _storiesFromRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((row) => row['id'] as String).toList();
    final views = await _countsFor('story_views', 'story_id', ids);
    final stars = await _countsFor('story_likes', 'story_id', ids);
    final viewed = await restoreViewedStoryIds();
    final viewers = await _viewersFor(ids);
    final currentUserId = _currentUserId;
    return rows
        .map(
          (row) => _storyFromRow(
            row,
            views: views[row['id']] ?? 0,
            stars: stars[row['id']] ?? 0,
            viewers: viewers[row['id']] ?? const [],
            viewed: viewed.contains(row['id']),
            isOwn: currentUserId != null && row['author_id'] == currentUserId,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, int>> _countsFor(
    String table,
    String column,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final rows = await _client.from(table).select(column).inFilter(column, ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row[column] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, List<StoryViewer>>> _viewersFor(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('story_views')
        .select(
          'story_id,viewed_at,'
          'profiles:viewer_id(id,name,username,avatar_asset,avatar_url)',
        )
        .inFilter('story_id', ids)
        .order('viewed_at', ascending: false);
    final byStory = <String, List<StoryViewer>>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final storyId = row['story_id'] as String?;
      if (storyId == null) continue;
      final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
      byStory
          .putIfAbsent(storyId, () => [])
          .add(
            StoryViewer(
              id: profile['id'] as String? ?? '',
              name: _string(profile, 'name', 'Fan Hallyu'),
              username: _normalizeUsername(_string(profile, 'username', 'fan')),
              avatarAsset: _string(
                profile,
                'avatar_url',
                _string(
                  profile,
                  'avatar_asset',
                  'assets/demo-users/user-01.jpg',
                ),
              ),
              action: 'Vio tu historia',
            ),
          );
    }
    return byStory;
  }

  Story _storyFromRow(
    Map<String, dynamic> row, {
    required int views,
    required int stars,
    required List<StoryViewer> viewers,
    required bool viewed,
    required bool isOwn,
  }) {
    final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final media =
        ((row['story_media'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
          ..sort(
            (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
              (b['sort_order'] as num?)?.toInt() ?? 0,
            ),
          ));
    final firstMedia = media.isEmpty ? null : media.first;
    final mediaUrl = _mediaUrl(firstMedia);
    final contentType = _contentType(row['content_type'] as String?);
    final transform =
        (row['media_transform'] as Map?)?.cast<String, dynamic>() ??
        ((firstMedia?['transform'] as Map?)?.cast<String, dynamic>() ?? {});
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    return Story(
      id: row['id'] as String,
      authorId: row['author_id'] as String? ?? '',
      name: _string(profile, 'name', 'Hallyu Fan'),
      fandom: _string(profile, 'fandom', 'Hallyu'),
      avatarAsset: _string(
        profile,
        'avatar_url',
        _string(profile, 'avatar_asset', ''),
      ),
      imageAsset: contentType == StoryContentType.video ? '' : mediaUrl,
      mediaPath: contentType == StoryContentType.video ? mediaUrl : '',
      title: row['title'] as String? ?? '',
      detail: row['detail'] as String? ?? '',
      music: row['music'] as String? ?? '',
      musicAsset: row['music_asset'] as String? ?? '',
      text: row['text'] as String? ?? '',
      elements: _elementsFromJson(row['elements']),
      mediaScale: (transform['scale'] as num?)?.toDouble() ?? 1,
      mediaOffset: Offset(
        (transform['offset_dx'] as num?)?.toDouble() ?? 0,
        (transform['offset_dy'] as num?)?.toDouble() ?? 0,
      ),
      mediaRotation: (transform['rotation'] as num?)?.toDouble() ?? 0,
      videoTrimStartSeconds: (transform['trim_start'] as num?)?.toDouble() ?? 0,
      videoTrimEndSeconds: (transform['trim_end'] as num?)?.toDouble(),
      videoMuted: transform['muted'] as bool? ?? false,
      timeLabel: viewed ? 'Vista' : _relativeTime(createdAt),
      durationSeconds: _durationFromRow(row),
      contentType: contentType,
      backgroundColors: _colorsFromRow(row['background_colors']),
      visualFilter: _visualFilter(row['visual_filter'] as String?),
      audienceType: StoryAudienceType.fromStorage(
        row['audience_type'] as String?,
      ),
      sharedContentType: row['shared_content_type'] as String? ?? '',
      sharedContentId: row['shared_content_id'] as String? ?? '',
      viewers: viewers,
      views: views,
      stars: stars,
      createdAt: createdAt,
      isOwn: isOwn,
    );
  }

  Future<_StoredStoryMedia?> _storeMedia(
    String userId,
    String storyId,
    StoryDraft draft,
  ) async {
    if (draft.type == StoryContentType.text) return null;
    final fallback = draft.imageAsset.isNotEmpty
        ? draft.imageAsset
        : draft.mediaPath;
    final bytes = await _mediaBytes(draft);
    if (bytes == null) {
      if (fallback.isEmpty) return null;
      return _StoredStoryMedia(
        bucket: fallback.startsWith('assets/') ? 'asset' : 'external',
        path: fallback,
        publicUrl: fallback,
      );
    }
    if (bytes.isEmpty) {
      throw const StoryServiceException(
        'El archivo parece estar vacío o no se pudo leer.',
      );
    }
    if (draft.type == StoryContentType.video &&
        bytes.lengthInBytes > _maxVideoBytes) {
      throw const StoryServiceException(
        'El video supera 50 MB. Elegí uno más liviano por ahora.',
      );
    }
    if (draft.type != StoryContentType.video &&
        bytes.lengthInBytes > _maxImageBytes) {
      throw const StoryServiceException('La imagen supera el límite de 10 MB.');
    }
    if (draft.type != StoryContentType.video &&
        MediaUploadLimits.detectImageContentType(bytes) == null) {
      throw const StoryServiceException(
        'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
      );
    }
    final contentType = draft.type == StoryContentType.video
        ? _videoContentType(draft)
        : _imageContentType(bytes);
    final extension = _extensionForContentType(contentType);
    final path =
        '$userId/$storyId/story-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('story_media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );
    return _StoredStoryMedia(
      bucket: 'story_media',
      path: path,
      publicUrl: _client.storage.from('story_media').getPublicUrl(path),
      contentType: contentType,
      fileSizeBytes: bytes.lengthInBytes,
    );
  }

  Future<Uint8List?> _mediaBytes(StoryDraft draft) async {
    final bytes = draft.imageBytes;
    if (bytes != null) return bytes;
    final path = draft.mediaPath;
    if (path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('assets/')) {
      return null;
    }
    try {
      return XFile(path).readAsBytes();
    } catch (_) {
      throw const StoryServiceException(
        'No pudimos leer el archivo de la historia.',
      );
    }
  }

  Future<void> _cleanupFailedPublish(
    String userId,
    String storyId,
    _StoredStoryMedia? uploadedMedia,
  ) async {
    try {
      await _client
          .from('stories')
          .delete()
          .eq('id', storyId)
          .eq('author_id', userId);
    } catch (_) {}
    if (uploadedMedia?.bucket == 'story_media' &&
        uploadedMedia?.path.isNotEmpty == true) {
      try {
        await _client.storage.from('story_media').remove([uploadedMedia!.path]);
      } catch (_) {}
    }
  }

  Map<String, dynamic> _transformFor(
    StoryDraft draft, {
    _StoredStoryMedia? stored,
  }) {
    return {
      'scale': draft.mediaScale,
      'offset_dx': draft.mediaOffset.dx,
      'offset_dy': draft.mediaOffset.dy,
      'rotation': draft.mediaRotation,
      'trim_start': draft.videoTrimStartSeconds,
      'trim_end': draft.videoTrimEndSeconds,
      'muted': draft.videoMuted,
      if (stored != null) ...{
        'mime_type': stored.contentType,
        'file_size_bytes': stored.fileSizeBytes,
      },
    };
  }

  Map<String, dynamic> _elementToJson(StoryElement element) {
    return {
      'id': element.id,
      'type': element.type.name,
      'content': element.content,
      'x': element.position.dx,
      'y': element.position.dy,
      'scale': element.scale,
      'rotation': element.rotation,
      'color': element.color.toARGB32(),
      if (element.backgroundColor != null)
        'backgroundColor': element.backgroundColor!.toARGB32(),
      if (element.imageBytes != null)
        'imageBytes': base64Encode(element.imageBytes!),
    };
  }

  List<StoryElement> _elementsFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .map(_elementFromJson)
        .toList(growable: false);
  }

  StoryElement _elementFromJson(Map<String, dynamic> json) {
    final backgroundColor = json['backgroundColor'] as int?;
    final imageBytes = json['imageBytes'] as String?;
    return StoryElement(
      id: json['id'] as String? ?? '',
      type: _elementType(json['type'] as String?),
      content: json['content'] as String? ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0.5,
        (json['y'] as num?)?.toDouble() ?? 0.5,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      color: Color((json['color'] as num?)?.toInt() ?? Colors.white.toARGB32()),
      backgroundColor: backgroundColor == null ? null : Color(backgroundColor),
      imageBytes: imageBytes == null ? null : base64Decode(imageBytes),
    );
  }

  String _mediaUrl(Map<String, dynamic>? media) {
    if (media == null) return '';
    final publicUrl = media['public_url'] as String? ?? '';
    if (publicUrl.isNotEmpty) return publicUrl;
    final bucket = media['storage_bucket'] as String? ?? '';
    final path = media['storage_path'] as String? ?? '';
    if (path.isEmpty) return '';
    if (bucket == 'story_media') {
      return _client.storage.from('story_media').getPublicUrl(path);
    }
    return path;
  }

  int _durationForDraft(StoryDraft draft) {
    if (draft.type == StoryContentType.video) return _videoDuration(draft);
    return 5;
  }

  int _videoDuration(StoryDraft draft) {
    final trimEnd = draft.videoTrimEndSeconds ?? 60;
    return ((trimEnd - draft.videoTrimStartSeconds).ceil().clamp(1, 60) as num)
        .toInt();
  }

  int _durationFromRow(Map<String, dynamic> row) {
    return (((row['duration_seconds'] as num?)?.toInt() ?? 5).clamp(1, 60)
            as num)
        .toInt();
  }

  List<Color> _colorsFromRow(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value
          .whereType<num>()
          .map((color) => Color(color.toInt()))
          .toList(growable: false);
    }
    return const [Color(0xFFEF4F7A), Color(0xFFA855F7)];
  }

  StoryContentType _contentType(String? value) {
    return StoryContentType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => StoryContentType.image,
    );
  }

  StoryElementType _elementType(String? value) {
    return StoryElementType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => StoryElementType.sticker,
    );
  }

  StoryVisualFilter _visualFilter(String? value) {
    return StoryVisualFilter.values.firstWhere(
      (filter) => filter.name == value,
      orElse: () => StoryVisualFilter.original,
    );
  }

  String _imageContentType(Uint8List bytes) {
    final contentType = MediaUploadLimits.detectImageContentType(bytes);
    if (contentType == null) {
      throw const StoryServiceException(
        'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
      );
    }
    return contentType;
  }

  String _videoContentType(StoryDraft draft) {
    final source = draft.mediaPath.toLowerCase();
    if (source.contains('.mov')) return 'video/quicktime';
    if (source.contains('.webm')) return 'video/webm';
    if (source.contains('.mp4') || source.contains('.m4v')) {
      return 'video/mp4';
    }
    return 'video/mp4';
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

  String _normalizeUsername(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '@fan';
    return clean.startsWith('@') ? clean : '@$clean';
  }

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Ahora';
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  static const _storySelect =
      'id,author_id,title,detail,text,music,music_asset,content_type,'
      'duration_seconds,visual_filter,background_colors,elements,'
      'media_transform,audience_type,shared_content_type,shared_content_id,'
      'expires_at,created_at,'
      'profiles:author_id(id,name,username,avatar_asset,avatar_url,fandom),'
      'story_media(id,media_type,storage_bucket,storage_path,public_url,sort_order,transform)';
}

class _StoredStoryMedia {
  const _StoredStoryMedia({
    required this.bucket,
    required this.path,
    required this.publicUrl,
    this.contentType = '',
    this.fileSizeBytes,
  });

  final String bucket;
  final String path;
  final String publicUrl;
  final String contentType;
  final int? fileSizeBytes;
}
