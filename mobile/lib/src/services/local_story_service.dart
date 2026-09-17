import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_data.dart';
import '../models.dart';
import 'media_upload_limits.dart';
import 'story_time.dart';

class StoryServiceException implements Exception {
  const StoryServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalStoryService {
  const LocalStoryService();

  static const _ownStoriesKey = 'hallyuhub.own-stories.v2';
  static const _storyArchiveKey = 'hallyuhub.story-archive.v1';
  static const _viewedStoriesKey = 'hallyuhub.viewed-stories.v1';
  static const _starredStoriesKey = 'hallyuhub.starred-stories.v1';
  static const _storyLifetime = Duration(hours: 24);
  static const _maxStories = 12;
  static const _maxArchivedStories = 120;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealStories => false;

  Future<List<Story>> restoreOwnStories() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_ownStoriesKey);
    if (stored == null) return [];
    try {
      final now = DateTime.now();
      final entries = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final restoredStories = entries.map(_storyFromJson).toList();
      final activeStories = restoredStories
          .where(
            (story) =>
                story.createdAt != null &&
                now.difference(story.createdAt!) < _storyLifetime,
          )
          .toList();
      if (activeStories.length != entries.length) {
        final expiredStories = restoredStories
            .where((story) => !activeStories.contains(story))
            .toList();
        await _mergeIntoArchive(expiredStories);
        await saveOwnStories(activeStories);
      }
      return activeStories;
    } catch (_) {
      await preferences.remove(_ownStoriesKey);
      return [];
    }
  }

  Future<void> saveOwnStories(List<Story> stories) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = stories.take(_maxStories).map(_storyToJson).toList();
    await preferences.setString(_ownStoriesKey, jsonEncode(entries));
  }

  Future<List<Story>> restoreFollowingStories({
    Set<String> followingIds = const {},
  }) async {
    if (followingIds.isEmpty) return [];
    return stories
        .where((story) => followingIds.contains(story.authorId))
        .toList(growable: false);
  }

  Future<void> deleteStory(String storyId) async {
    final activeStories = await restoreOwnStories();
    final nextStories = activeStories
        .where((story) => story.id != storyId)
        .toList(growable: false);
    await saveOwnStories(nextStories);
    final archive = await restoreStoryArchive();
    await _saveStoryArchive(
      archive.where((story) => story.id != storyId).toList(growable: false),
    );
    final viewed = await restoreViewedStoryIds();
    if (viewed.remove(storyId)) await saveViewedStoryIds(viewed);
    final starred = await restoreStarredStoryIds();
    if (starred.remove(storyId)) await saveStarredStoryIds(starred);
    revision.value++;
  }

  Future<void> savePublishedStory(
    Story story,
    List<Story> activeStories,
  ) async {
    await saveOwnStories(activeStories);
    await _mergeIntoArchive([story]);
    revision.value++;
  }

  Future<Story> publish({
    required AuthUser author,
    required StoryDraft draft,
    Iterable<Story>? currentStories,
    List<StoryViewer> viewers = const [],
    int views = 0,
    int stars = 0,
  }) async {
    _validateDraft(draft);
    final activeStories = currentStories?.toList() ?? await restoreOwnStories();
    final story = Story(
      id: 'created-story-${DateTime.now().microsecondsSinceEpoch}',
      authorId: 'local-user',
      name: author.name,
      fandom: author.fandom,
      avatarAsset: author.avatarAsset,
      imageAsset:
          draft.imageAsset.isEmpty && draft.type != StoryContentType.text
          ? 'assets/demo-stories/story-01.jpg'
          : draft.imageAsset,
      imageBytes: draft.imageBytes,
      mediaPath: draft.mediaPath,
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
      durationSeconds: draft.type == StoryContentType.video
          ? ((draft.videoTrimEndSeconds ?? 60) - draft.videoTrimStartSeconds)
                .ceil()
                .clamp(1, 60)
          : 5,
      contentType: draft.type,
      backgroundColors: draft.backgroundColors,
      visualFilter: draft.visualFilter,
      viewers: viewers,
      views: views,
      stars: stars,
      createdAt: DateTime.now(),
      taggedPeople: draft.taggedPeople,
      taggedUserIds: draft.taggedUserIds,
      audienceType: draft.audienceType,
      audienceUserIds: draft.audienceUserIds,
      sharedContentType: draft.sharedContentType,
      sharedContentId: draft.sharedContentId,
      isOwn: true,
    );
    activeStories.insert(0, story);
    await savePublishedStory(story, activeStories);
    return story;
  }

  void _validateDraft(StoryDraft draft) {
    final bytes = draft.imageBytes;
    if (draft.type == StoryContentType.video &&
        ((draft.videoTrimEndSeconds ?? 60) - draft.videoTrimStartSeconds) >
            MediaUploadLimits.storyVideoDurationSeconds) {
      throw const StoryServiceException(
        'Las historias de video pueden durar hasta 60 segundos durante el acceso anticipado.',
      );
    }
    if (bytes == null) return;
    if (bytes.isEmpty) {
      throw const StoryServiceException(
        'El archivo parece estar vacío o no se pudo leer.',
      );
    }
    if (draft.type == StoryContentType.video &&
        bytes.lengthInBytes > MediaUploadLimits.storyVideoBytes) {
      throw const StoryServiceException(
        'El video supera 50 MB. Elegí uno más liviano por ahora.',
      );
    }
    if (draft.type != StoryContentType.video &&
        bytes.lengthInBytes > MediaUploadLimits.imageBytes) {
      throw const StoryServiceException('La imagen supera el límite de 10 MB.');
    }
    if (draft.type != StoryContentType.video &&
        MediaUploadLimits.detectImageContentType(bytes) == null) {
      throw const StoryServiceException(
        'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
      );
    }
  }

  Future<void> updateOwnStoryProfile(AuthUser author) async {
    final activeStories = await restoreOwnStories();
    final updatedActive = activeStories
        .map(
          (story) => story.isOwn || story.authorId == 'local-user'
              ? story.copyWith(
                  name: author.name,
                  fandom: author.fandom,
                  avatarAsset: author.avatarAsset,
                )
              : story,
        )
        .toList();
    await saveOwnStories(updatedActive);

    final archive = await restoreStoryArchive();
    final updatedArchive = archive
        .map(
          (story) => story.isOwn || story.authorId == 'local-user'
              ? story.copyWith(
                  name: author.name,
                  fandom: author.fandom,
                  avatarAsset: author.avatarAsset,
                )
              : story,
        )
        .toList();
    await _saveStoryArchive(updatedArchive);
    revision.value++;
  }

  Future<List<Story>> restoreStoryArchive() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storyArchiveKey);
    if (stored == null) return [];
    try {
      final archive = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_storyFromJson)
          .toList();
      archive.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return archive;
    } catch (_) {
      await preferences.remove(_storyArchiveKey);
      return [];
    }
  }

  Future<Story> repostFromArchive(Story archivedStory) async {
    final originalDate =
        archivedStory.originalCreatedAt ??
        archivedStory.createdAt ??
        DateTime.now();
    final memory = archivedStory.copyWith(
      id: 'memory-story-${DateTime.now().microsecondsSinceEpoch}',
      title: archivedStory.title,
      detail: archivedStory.detail,
      createdAt: DateTime.now(),
      originalCreatedAt: originalDate,
      memoryLabel: memoryLabelFor(originalDate),
      viewers: const [],
      views: 0,
      stars: 0,
      isOwn: true,
    );
    final activeStories = await restoreOwnStories();
    activeStories.insert(0, memory);
    await saveOwnStories(activeStories);
    await _mergeIntoArchive([memory]);
    revision.value++;
    return memory;
  }

  Future<void> _mergeIntoArchive(List<Story> stories) async {
    if (stories.isEmpty) return;
    final existing = await restoreStoryArchive();
    final byId = {for (final story in existing) story.id: story};
    for (final story in stories) {
      byId[story.id] = story;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storyArchiveKey,
      jsonEncode(merged.take(_maxArchivedStories).map(_storyToJson).toList()),
    );
  }

  Future<Set<String>> restoreViewedStoryIds() =>
      _restoreIdSet(_viewedStoriesKey);

  Future<void> saveViewedStoryIds(Set<String> ids) =>
      _saveIdSet(_viewedStoriesKey, ids);

  Future<Set<String>> restoreStarredStoryIds() =>
      _restoreIdSet(_starredStoriesKey);

  Future<void> saveStarredStoryIds(Set<String> ids) =>
      _saveIdSet(_starredStoriesKey, ids);

  Future<Set<String>> _restoreIdSet(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(key) ?? const []).toSet();
  }

  Future<void> _saveIdSet(String key, Set<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(key, ids.toList());
  }

  Story _storyFromJson(Map<String, dynamic> json) {
    final imageBytes = json['imageBytes'] as String?;
    final backgroundColors =
        (json['backgroundColors'] as List<dynamic>? ?? const [])
            .cast<int>()
            .map(Color.new)
            .toList();
    return Story(
      id: json['id'] as String,
      authorId: json['authorId'] as String? ?? 'local-user',
      name: json['name'] as String? ?? 'Tu historia',
      fandom: json['fandom'] as String? ?? 'Ahora',
      avatarAsset:
          json['avatarAsset'] as String? ??
          'assets/demo-users/ai-luna-rivas.png',
      imageAsset:
          json['imageAsset'] as String? ?? 'assets/demo-stories/story-01.jpg',
      imageBytes: imageBytes == null ? null : base64Decode(imageBytes),
      mediaPath: json['mediaPath'] as String? ?? '',
      title: json['title'] as String? ?? 'Mi historia',
      detail: json['detail'] as String? ?? '',
      music: json['music'] as String? ?? '',
      musicAsset: json['musicAsset'] as String? ?? '',
      text: json['text'] as String? ?? '',
      elements: (json['elements'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_elementFromJson)
          .toList(),
      mediaScale: (json['mediaScale'] as num?)?.toDouble() ?? 1,
      mediaOffset: Offset(
        (json['mediaOffsetX'] as num?)?.toDouble() ?? 0,
        (json['mediaOffsetY'] as num?)?.toDouble() ?? 0,
      ),
      mediaRotation: (json['mediaRotation'] as num?)?.toDouble() ?? 0,
      videoTrimStartSeconds:
          (json['videoTrimStartSeconds'] as num?)?.toDouble() ?? 0,
      videoTrimEndSeconds: (json['videoTrimEndSeconds'] as num?)?.toDouble(),
      videoMuted: json['videoMuted'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int? ?? 5,
      contentType: StoryContentType.values.byName(
        json['contentType'] as String? ?? StoryContentType.image.name,
      ),
      backgroundColors: backgroundColors.isEmpty
          ? const [Color(0xFFEF4F7A), Color(0xFFA855F7)]
          : backgroundColors,
      visualFilter: StoryVisualFilter.values.byName(
        json['visualFilter'] as String? ?? StoryVisualFilter.original.name,
      ),
      viewers: (json['viewers'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_viewerFromJson)
          .toList(),
      views: json['views'] as int? ?? 0,
      stars: json['stars'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      originalCreatedAt: json['originalCreatedAt'] == null
          ? null
          : DateTime.parse(json['originalCreatedAt'] as String),
      memoryLabel: json['memoryLabel'] as String? ?? '',
      audienceType: StoryAudienceType.fromStorage(
        json['audienceType'] as String?,
      ),
      audienceUserIds: (json['audienceUserIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      sharedContentType: json['sharedContentType'] as String? ?? '',
      sharedContentId: json['sharedContentId'] as String? ?? '',
      isOwn: json['isOwn'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _storyToJson(Story story) {
    return {
      'id': story.id,
      'authorId': story.authorId,
      'name': story.name,
      'fandom': story.fandom,
      'avatarAsset': story.avatarAsset,
      if (story.imageBytes != null)
        'imageBytes': base64Encode(story.imageBytes!),
      'imageAsset': story.imageAsset,
      'mediaPath': story.mediaPath,
      'title': story.title,
      'detail': story.detail,
      'music': story.music,
      'musicAsset': story.musicAsset,
      'text': story.text,
      'elements': story.elements.map(_elementToJson).toList(),
      'mediaScale': story.mediaScale,
      'mediaOffsetX': story.mediaOffset.dx,
      'mediaOffsetY': story.mediaOffset.dy,
      'mediaRotation': story.mediaRotation,
      'videoTrimStartSeconds': story.videoTrimStartSeconds,
      'videoTrimEndSeconds': story.videoTrimEndSeconds,
      'videoMuted': story.videoMuted,
      'durationSeconds': story.durationSeconds,
      'contentType': story.contentType.name,
      'backgroundColors': story.backgroundColors
          .map((color) => color.toARGB32())
          .toList(),
      'visualFilter': story.visualFilter.name,
      'viewers': story.viewers.map(_viewerToJson).toList(),
      'views': story.views,
      'stars': story.stars,
      'createdAt': (story.createdAt ?? DateTime.now()).toIso8601String(),
      if (story.originalCreatedAt != null)
        'originalCreatedAt': story.originalCreatedAt!.toIso8601String(),
      'memoryLabel': story.memoryLabel,
      'audienceType': story.audienceType.storageValue,
      'audienceUserIds': story.audienceUserIds,
      'sharedContentType': story.sharedContentType,
      'sharedContentId': story.sharedContentId,
      'isOwn': story.isOwn,
    };
  }

  Future<void> _saveStoryArchive(List<Story> archive) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = [...archive]
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    await preferences.setString(
      _storyArchiveKey,
      jsonEncode(sorted.take(_maxArchivedStories).map(_storyToJson).toList()),
    );
  }

  StoryViewer _viewerFromJson(Map<String, dynamic> json) {
    return StoryViewer(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarAsset: json['avatarAsset'] as String,
      action: json['action'] as String,
      starred: json['starred'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _viewerToJson(StoryViewer viewer) {
    return {
      'id': viewer.id,
      'name': viewer.name,
      'username': viewer.username,
      'avatarAsset': viewer.avatarAsset,
      'action': viewer.action,
      'starred': viewer.starred,
    };
  }

  StoryElement _elementFromJson(Map<String, dynamic> json) {
    final backgroundColor = json['backgroundColor'] as int?;
    final imageBytes = json['imageBytes'] as String?;
    return StoryElement(
      id: json['id'] as String,
      type: StoryElementType.values.byName(
        json['type'] as String? ?? StoryElementType.sticker.name,
      ),
      content: json['content'] as String? ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0.5,
        (json['y'] as num?)?.toDouble() ?? 0.5,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      color: Color(json['color'] as int? ?? Colors.white.toARGB32()),
      backgroundColor: backgroundColor == null ? null : Color(backgroundColor),
      imageBytes: imageBytes == null ? null : base64Decode(imageBytes),
    );
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
}
