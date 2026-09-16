import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'services/age_policy.dart';

import 'data/legal_documents.dart';

enum StoryContentType { image, text, video }

enum StoryElementType { text, sticker, image }

enum StoryVisualFilter {
  original('Original'),
  hallyuGlow('Hallyu Glow'),
  neonPink('Neon Pink'),
  softPastel('Soft Pastel'),
  concertLight('Concert Light'),
  vintage('Vintage'),
  blackPink('Black & Pink'),
  purpleStage('Purple Stage');

  const StoryVisualFilter(this.label);

  final String label;
}

class StoryMusic {
  const StoryMusic({
    required this.id,
    required this.title,
    required this.artist,
    required this.assetPath,
    required this.color,
    this.mood = 'Pop suave',
    this.durationSeconds = 6,
  });

  final String id;
  final String title;
  final String artist;
  final String assetPath;
  final Color color;
  final String mood;
  final int durationSeconds;

  String get label => '$artist · $title';

  String get durationLabel {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class StoryElement {
  const StoryElement({
    required this.id,
    required this.type,
    required this.content,
    this.position = const Offset(0.5, 0.5),
    this.scale = 1,
    this.rotation = 0,
    this.color = Colors.white,
    this.backgroundColor,
    this.imageBytes,
  });

  final String id;
  final StoryElementType type;
  final String content;
  final Offset position;
  final double scale;
  final double rotation;
  final Color color;
  final Color? backgroundColor;
  final Uint8List? imageBytes;

  StoryElement copyWith({
    String? id,
    StoryElementType? type,
    String? content,
    Offset? position,
    double? scale,
    double? rotation,
    Color? color,
    Color? backgroundColor,
    bool clearBackgroundColor = false,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
  }) {
    return StoryElement(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      color: color ?? this.color,
      backgroundColor: clearBackgroundColor
          ? null
          : backgroundColor ?? this.backgroundColor,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
    );
  }
}

class StoryViewer {
  const StoryViewer({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarAsset,
    required this.action,
    this.starred = false,
  });

  final String id;
  final String name;
  final String username;
  final String avatarAsset;
  final String action;
  final bool starred;
}

class StoryDraft {
  const StoryDraft({
    required this.type,
    this.text = '',
    this.imageAsset = '',
    this.imageBytes,
    this.mediaPath = '',
    this.title = '',
    this.detail = '',
    this.music = '',
    this.musicAsset = '',
    this.elements = const [],
    this.mediaScale = 1,
    this.mediaOffset = Offset.zero,
    this.mediaRotation = 0,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.videoMuted = false,
    this.backgroundColors = const [Color(0xFFEF4F7A), Color(0xFFA855F7)],
    this.visualFilter = StoryVisualFilter.original,
    this.taggedPeople = const [],
    this.taggedUserIds = const [],
    this.taggedUsers = const [],
    this.taggedEntities = const [],
  });

  final StoryContentType type;
  final String text;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final String title;
  final String detail;
  final String music;
  final String musicAsset;
  final List<StoryElement> elements;
  final double mediaScale;
  final Offset mediaOffset;
  final double mediaRotation;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool videoMuted;
  final List<Color> backgroundColors;
  final StoryVisualFilter visualFilter;
  final List<String> taggedPeople;
  final List<String> taggedUserIds;
  final List<CommunityProfile> taggedUsers;
  final List<KpopEntity> taggedEntities;

  StoryDraft copyWith({
    StoryContentType? type,
    String? text,
    String? imageAsset,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
    String? mediaPath,
    String? title,
    String? detail,
    String? music,
    String? musicAsset,
    List<StoryElement>? elements,
    double? mediaScale,
    Offset? mediaOffset,
    double? mediaRotation,
    double? videoTrimStartSeconds,
    double? videoTrimEndSeconds,
    bool clearVideoTrimEndSeconds = false,
    bool? videoMuted,
    List<Color>? backgroundColors,
    StoryVisualFilter? visualFilter,
    List<String>? taggedPeople,
    List<String>? taggedUserIds,
    List<CommunityProfile>? taggedUsers,
    List<KpopEntity>? taggedEntities,
  }) {
    return StoryDraft(
      type: type ?? this.type,
      text: text ?? this.text,
      imageAsset: imageAsset ?? this.imageAsset,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      mediaPath: mediaPath ?? this.mediaPath,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      music: music ?? this.music,
      musicAsset: musicAsset ?? this.musicAsset,
      elements: elements ?? this.elements,
      mediaScale: mediaScale ?? this.mediaScale,
      mediaOffset: mediaOffset ?? this.mediaOffset,
      mediaRotation: mediaRotation ?? this.mediaRotation,
      videoTrimStartSeconds:
          videoTrimStartSeconds ?? this.videoTrimStartSeconds,
      videoTrimEndSeconds: clearVideoTrimEndSeconds
          ? null
          : videoTrimEndSeconds ?? this.videoTrimEndSeconds,
      videoMuted: videoMuted ?? this.videoMuted,
      backgroundColors: backgroundColors ?? this.backgroundColors,
      visualFilter: visualFilter ?? this.visualFilter,
      taggedPeople: taggedPeople ?? this.taggedPeople,
      taggedUserIds: taggedUserIds ?? this.taggedUserIds,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      taggedEntities: taggedEntities ?? this.taggedEntities,
    );
  }
}

class StoryTemplate {
  const StoryTemplate({
    required this.id,
    required this.title,
    required this.detail,
    required this.imageAsset,
    required this.music,
    this.musicAsset = '',
  });

  final String id;
  final String title;
  final String detail;
  final String imageAsset;
  final String music;
  final String musicAsset;
}

class Story {
  const Story({
    required this.id,
    required this.authorId,
    required this.name,
    required this.fandom,
    required this.avatarAsset,
    required this.imageAsset,
    this.imageBytes,
    this.mediaPath = '',
    this.title = '',
    this.detail = '',
    this.music = '',
    this.musicAsset = '',
    this.text = '',
    this.elements = const [],
    this.mediaScale = 1,
    this.mediaOffset = Offset.zero,
    this.mediaRotation = 0,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.videoMuted = false,
    this.timeLabel = 'Ahora',
    this.durationSeconds = 5,
    this.contentType = StoryContentType.image,
    this.backgroundColors = const [Color(0xFFEF4F7A), Color(0xFFA855F7)],
    this.visualFilter = StoryVisualFilter.original,
    this.viewers = const [],
    this.views = 0,
    this.stars = 0,
    this.createdAt,
    this.originalCreatedAt,
    this.memoryLabel = '',
    this.taggedPeople = const [],
    this.taggedUserIds = const [],
    this.taggedEntities = const [],
    this.isLive = false,
    this.isOwn = false,
  });

  final String id;
  final String authorId;
  final String name;
  final String fandom;
  final String avatarAsset;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final String title;
  final String detail;
  final String music;
  final String musicAsset;
  final String text;
  final List<StoryElement> elements;
  final double mediaScale;
  final Offset mediaOffset;
  final double mediaRotation;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool videoMuted;
  final String timeLabel;
  final int durationSeconds;
  final StoryContentType contentType;
  final List<Color> backgroundColors;
  final StoryVisualFilter visualFilter;
  final List<StoryViewer> viewers;
  final int views;
  final int stars;
  final DateTime? createdAt;
  final DateTime? originalCreatedAt;
  final String memoryLabel;
  final List<String> taggedPeople;
  final List<String> taggedUserIds;
  final List<KpopEntity> taggedEntities;
  final bool isLive;
  final bool isOwn;

  Story copyWith({
    String? id,
    String? authorId,
    String? name,
    String? fandom,
    String? avatarAsset,
    String? imageAsset,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
    String? mediaPath,
    String? title,
    String? detail,
    String? music,
    String? musicAsset,
    String? text,
    List<StoryElement>? elements,
    double? mediaScale,
    Offset? mediaOffset,
    double? mediaRotation,
    double? videoTrimStartSeconds,
    double? videoTrimEndSeconds,
    bool clearVideoTrimEndSeconds = false,
    bool? videoMuted,
    String? timeLabel,
    int? durationSeconds,
    StoryContentType? contentType,
    List<Color>? backgroundColors,
    StoryVisualFilter? visualFilter,
    List<StoryViewer>? viewers,
    int? views,
    int? stars,
    DateTime? createdAt,
    DateTime? originalCreatedAt,
    String? memoryLabel,
    List<String>? taggedPeople,
    List<String>? taggedUserIds,
    List<KpopEntity>? taggedEntities,
    bool? isLive,
    bool? isOwn,
  }) {
    return Story(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      name: name ?? this.name,
      fandom: fandom ?? this.fandom,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      imageAsset: imageAsset ?? this.imageAsset,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      mediaPath: mediaPath ?? this.mediaPath,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      music: music ?? this.music,
      musicAsset: musicAsset ?? this.musicAsset,
      text: text ?? this.text,
      elements: elements ?? this.elements,
      mediaScale: mediaScale ?? this.mediaScale,
      mediaOffset: mediaOffset ?? this.mediaOffset,
      mediaRotation: mediaRotation ?? this.mediaRotation,
      videoTrimStartSeconds:
          videoTrimStartSeconds ?? this.videoTrimStartSeconds,
      videoTrimEndSeconds: clearVideoTrimEndSeconds
          ? null
          : videoTrimEndSeconds ?? this.videoTrimEndSeconds,
      videoMuted: videoMuted ?? this.videoMuted,
      timeLabel: timeLabel ?? this.timeLabel,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      contentType: contentType ?? this.contentType,
      backgroundColors: backgroundColors ?? this.backgroundColors,
      visualFilter: visualFilter ?? this.visualFilter,
      viewers: viewers ?? this.viewers,
      views: views ?? this.views,
      stars: stars ?? this.stars,
      createdAt: createdAt ?? this.createdAt,
      originalCreatedAt: originalCreatedAt ?? this.originalCreatedAt,
      memoryLabel: memoryLabel ?? this.memoryLabel,
      taggedPeople: taggedPeople ?? this.taggedPeople,
      taggedUserIds: taggedUserIds ?? this.taggedUserIds,
      taggedEntities: taggedEntities ?? this.taggedEntities,
      isLive: isLive ?? this.isLive,
      isOwn: isOwn ?? this.isOwn,
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.storyId = '',
    this.storyPreview = '',
    this.mediaType = '',
    this.mediaUrl = '',
    this.storageBucket = '',
    this.storagePath = '',
    this.fileName = '',
    this.fileSize = 0,
    this.mimeType = '',
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final String storyId;
  final String storyPreview;
  final String mediaType;
  final String mediaUrl;
  final String storageBucket;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String mimeType;

  bool get isOwn => senderId == 'local-user';
  bool get repliesToStory => storyId.isNotEmpty;
  bool get hasMedia => mediaUrl.isNotEmpty || storagePath.isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
  String get previewText {
    final text = body.trim();
    if (text.isNotEmpty) return text;
    if (isImage) return 'Foto';
    if (isVideo) return 'Video';
    return '';
  }
}

class DirectMessageAttachmentDraft {
  const DirectMessageAttachmentDraft({
    required this.mediaType,
    required this.bytes,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  final String mediaType;
  final Uint8List bytes;
  final String fileName;
  final int fileSize;
  final String mimeType;

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
}

class DirectConversation {
  const DirectConversation({
    required this.profileId,
    required this.name,
    required this.username,
    required this.avatarAsset,
    required this.messages,
    this.unreadCount = 0,
  });

  final String profileId;
  final String name;
  final String username;
  final String avatarAsset;
  final List<DirectMessage> messages;
  final int unreadCount;

  DirectMessage? get latestMessage => messages.lastOrNull;

  DirectConversation copyWith({
    String? profileId,
    String? name,
    String? username,
    String? avatarAsset,
    List<DirectMessage>? messages,
    int? unreadCount,
  }) {
    return DirectConversation(
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class DirectMessageRequest {
  const DirectMessageRequest({
    required this.id,
    required this.profile,
    required this.message,
    required this.reason,
    required this.timeLabel,
  });

  final String id;
  final CommunityProfile profile;
  final String message;
  final String reason;
  final String timeLabel;
}

class HomeHighlight {
  const HomeHighlight({
    required this.label,
    required this.detail,
    required this.avatarAsset,
    required this.colors,
    this.active = false,
  });

  final String label;
  final String detail;
  final String avatarAsset;
  final List<Color> colors;
  final bool active;
}

class HomeBanner {
  const HomeBanner({
    required this.meta,
    required this.title,
    required this.colors,
  });

  final String meta;
  final String title;
  final List<Color> colors;
}

class HomeMetric {
  const HomeMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;
}

class CommunityProfile {
  const CommunityProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.city,
    required this.country,
    required this.fandom,
    required this.favoriteGroup,
    required this.bio,
    required this.avatarAsset,
    required this.followers,
    required this.posts,
    required this.colors,
    this.following = '0',
    this.starsReceived = '0',
    this.level = 1,
    this.coverAsset = 'assets/demo-posts/post-01.jpg',
    this.online = false,
    this.privateProfile = false,
    this.role = 'user',
  });

  final String id;
  final String name;
  final String username;
  final String city;
  final String country;
  final String fandom;
  final String favoriteGroup;
  final String bio;
  final String avatarAsset;
  final String followers;
  final String posts;
  final List<Color> colors;
  final String following;
  final String starsReceived;
  final int level;
  final String coverAsset;
  final bool online;
  final bool privateProfile;
  final String role;

  bool get canModeratePrivateContent {
    final normalized = role.trim().toLowerCase();
    return normalized == 'admin' || normalized == 'moderator';
  }
}

class HallyuNotification {
  const HallyuNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.actorId = '',
    this.actor,
    this.metadata = const {},
  });

  final String id;
  final String recipientId;
  final String actorId;
  final CommunityProfile? actor;
  final String type;
  final String entityType;
  final String entityId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  HallyuNotification copyWith({bool? isRead}) {
    return HallyuNotification(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      actor: actor,
      type: type,
      entityType: entityType,
      entityId: entityId,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      metadata: metadata,
    );
  }
}

enum CollectionItemCategory {
  photocard('Photocard'),
  album('Álbum'),
  lightstick('Lightstick'),
  merch('Merch'),
  fanmade('Fanmade'),
  poster('Poster'),
  other('Otro');

  const CollectionItemCategory(this.label);

  final String label;
}

enum CollectionItemStatus {
  inCollection('En colección'),
  availableForTrade('Disponible para trade'),
  forSale('En venta'),
  reserved('Reservado'),
  sold('Vendido'),
  wishlist('Wishlist');

  const CollectionItemStatus(this.label);

  final String label;
}

enum CollectionVisibility {
  public('Visible para todos'),
  followers('Solo seguidores'),
  private('Privado');

  const CollectionVisibility(this.label);

  final String label;
}

enum WishlistPriority {
  low('Baja'),
  medium('Media'),
  high('Alta');

  const WishlistPriority(this.label);

  final String label;
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerUsername,
    required this.ownerAvatarAsset,
    required this.imageAsset,
    required this.title,
    required this.groupArtist,
    required this.category,
    required this.status,
    required this.description,
    required this.addedAt,
    this.imageBytes,
    this.eraAlbum = '',
    this.rarity = 'Standard',
    this.condition = 'Muy buen estado',
    this.city = '',
    this.country = '',
    this.price = '',
    this.currency = '',
    this.tradeLookingFor = '',
    this.tradeOptions = const [],
    this.references = const [],
    this.visibility = CollectionVisibility.public,
    this.priority = WishlistPriority.medium,
    this.note = '',
    this.source = 'demo_local',
    this.tags = const [],
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerUsername;
  final String ownerAvatarAsset;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String title;
  final String groupArtist;
  final String eraAlbum;
  final CollectionItemCategory category;
  final CollectionItemStatus status;
  final String description;
  final String addedAt;
  final String rarity;
  final String condition;
  final String city;
  final String country;
  final String price;
  final String currency;
  final String tradeLookingFor;
  final List<String> tradeOptions;
  final List<String> references;
  final CollectionVisibility visibility;
  final WishlistPriority priority;
  final String note;
  final String source;
  final List<String> tags;

  bool get isTrade => status == CollectionItemStatus.availableForTrade;
  bool get isSale =>
      status == CollectionItemStatus.forSale ||
      status == CollectionItemStatus.reserved ||
      status == CollectionItemStatus.sold;
  bool get isWishlist => status == CollectionItemStatus.wishlist;
  bool get isPublic => visibility == CollectionVisibility.public;

  CollectionItem copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? ownerUsername,
    String? ownerAvatarAsset,
    String? imageAsset,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
    String? title,
    String? groupArtist,
    String? eraAlbum,
    CollectionItemCategory? category,
    CollectionItemStatus? status,
    String? description,
    String? addedAt,
    String? rarity,
    String? condition,
    String? city,
    String? country,
    String? price,
    String? currency,
    String? tradeLookingFor,
    List<String>? tradeOptions,
    List<String>? references,
    CollectionVisibility? visibility,
    WishlistPriority? priority,
    String? note,
    String? source,
    List<String>? tags,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      ownerAvatarAsset: ownerAvatarAsset ?? this.ownerAvatarAsset,
      imageAsset: imageAsset ?? this.imageAsset,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      title: title ?? this.title,
      groupArtist: groupArtist ?? this.groupArtist,
      eraAlbum: eraAlbum ?? this.eraAlbum,
      category: category ?? this.category,
      status: status ?? this.status,
      description: description ?? this.description,
      addedAt: addedAt ?? this.addedAt,
      rarity: rarity ?? this.rarity,
      condition: condition ?? this.condition,
      city: city ?? this.city,
      country: country ?? this.country,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      tradeLookingFor: tradeLookingFor ?? this.tradeLookingFor,
      tradeOptions: tradeOptions ?? this.tradeOptions,
      references: references ?? this.references,
      visibility: visibility ?? this.visibility,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      source: source ?? this.source,
      tags: tags ?? this.tags,
    );
  }
}

enum PostMediaType { image, video }

class PostMediaItem {
  const PostMediaItem({
    required this.id,
    this.type = PostMediaType.image,
    this.imageAsset = '',
    this.imageBytes,
    this.mediaPath = '',
    this.fileName = '',
    this.mimeType = '',
    this.fileSizeBytes,
    this.mediaScale = 1,
    this.mediaOffset = Offset.zero,
    this.mediaRotation = 0,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.videoMuted = true,
  });

  final String id;
  final PostMediaType type;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final String fileName;
  final String mimeType;
  final int? fileSizeBytes;
  final double mediaScale;
  final Offset mediaOffset;
  final double mediaRotation;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool videoMuted;

  bool get isVideo => type == PostMediaType.video;
  bool get hasMedia =>
      imageBytes != null || imageAsset.isNotEmpty || mediaPath.isNotEmpty;

  PostMediaItem copyWith({
    String? id,
    PostMediaType? type,
    String? imageAsset,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
    String? mediaPath,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    bool clearFileSizeBytes = false,
    double? mediaScale,
    Offset? mediaOffset,
    double? mediaRotation,
    double? videoTrimStartSeconds,
    double? videoTrimEndSeconds,
    bool clearVideoTrimEndSeconds = false,
    bool? videoMuted,
  }) {
    return PostMediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      imageAsset: imageAsset ?? this.imageAsset,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      mediaPath: mediaPath ?? this.mediaPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: clearFileSizeBytes
          ? null
          : fileSizeBytes ?? this.fileSizeBytes,
      mediaScale: mediaScale ?? this.mediaScale,
      mediaOffset: mediaOffset ?? this.mediaOffset,
      mediaRotation: mediaRotation ?? this.mediaRotation,
      videoTrimStartSeconds:
          videoTrimStartSeconds ?? this.videoTrimStartSeconds,
      videoTrimEndSeconds: clearVideoTrimEndSeconds
          ? null
          : videoTrimEndSeconds ?? this.videoTrimEndSeconds,
      videoMuted: videoMuted ?? this.videoMuted,
    );
  }
}

class HubPost {
  const HubPost({
    required this.id,
    this.authorId = '',
    required this.author,
    required this.username,
    required this.avatarAsset,
    required this.imageAsset,
    required this.caption,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.mood,
    required this.time,
    required this.shares,
    required this.saves,
    this.location = '',
    this.imageBytes,
    this.mediaPath = '',
    this.containsVideo = false,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.videoMuted = true,
    this.mediaItems = const [],
    this.elements = const [],
    this.mediaScale = 1,
    this.mediaOffset = Offset.zero,
    this.mediaRotation = 0,
    this.music = '',
    this.musicAsset = '',
    this.filterIndex = 0,
    this.taggedPeople = const [],
    this.taggedUserIds = const [],
    this.taggedEntities = const [],
    this.artist = '',
    this.privacy = 'Todos',
    this.createdAt,
    this.isOwn = false,
    this.likedByCurrentUser = false,
    this.savedByCurrentUser = false,
  });

  final String id;
  final String authorId;
  final String author;
  final String username;
  final String avatarAsset;
  final String imageAsset;
  final String caption;
  final List<String> tags;
  final String likes;
  final String comments;
  final String mood;
  final String time;
  final String shares;
  final String saves;
  final String location;
  final Uint8List? imageBytes;
  final String mediaPath;
  final bool containsVideo;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool videoMuted;
  final List<PostMediaItem> mediaItems;
  final List<StoryElement> elements;
  final double mediaScale;
  final Offset mediaOffset;
  final double mediaRotation;
  final String music;
  final String musicAsset;
  final int filterIndex;
  final List<String> taggedPeople;
  final List<String> taggedUserIds;
  final List<KpopEntity> taggedEntities;
  final String artist;
  final String privacy;
  final DateTime? createdAt;
  final bool isOwn;
  final bool likedByCurrentUser;
  final bool savedByCurrentUser;

  List<PostMediaItem> get effectiveMediaItems {
    if (mediaItems.isNotEmpty) return mediaItems;
    if (imageBytes == null && imageAsset.isEmpty && mediaPath.isEmpty) {
      return const [];
    }
    return [
      PostMediaItem(
        id: '$id-single-media',
        type: containsVideo ? PostMediaType.video : PostMediaType.image,
        imageAsset: imageAsset,
        imageBytes: imageBytes,
        mediaPath: mediaPath,
        mediaScale: mediaScale,
        mediaOffset: mediaOffset,
        mediaRotation: mediaRotation,
        videoTrimStartSeconds: videoTrimStartSeconds,
        videoTrimEndSeconds: videoTrimEndSeconds,
        videoMuted: videoMuted,
      ),
    ];
  }

  bool get hasCarousel => effectiveMediaItems.length > 1;
  bool get hasVideoMedia => effectiveMediaItems.any((item) => item.isVideo);
}

/// Editorial information embedded in a post caption when a news item is
/// shared. Keeping this payload in the existing caption avoids requiring a
/// schema migration while preserving the user's own comment separately.
class SharedNewsPostContent {
  const SharedNewsPostContent({
    required this.title,
    required this.source,
    required this.summary,
    required this.articleUrl,
    this.imageUrl = '',
    this.publishedLabel = '',
  });

  static const _markerStart = '\n\n[[HALLYUHUB_NEWS_CARD_V1:';
  static const _markerEnd = ']]';

  final String title;
  final String source;
  final String summary;
  final String articleUrl;
  final String imageUrl;
  final String publishedLabel;

  String attachToComment(String comment) {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'title': title,
          'source': source,
          'summary': summary,
          'article_url': articleUrl,
          'image_url': imageUrl,
          'published_label': publishedLabel,
        }),
      ),
    );
    return '${comment.trim()}$_markerStart$payload$_markerEnd';
  }

  static ({String comment, SharedNewsPostContent? news}) fromCaption(
    String caption,
  ) {
    final markerIndex = caption.lastIndexOf(_markerStart);
    if (markerIndex < 0 || !caption.trimRight().endsWith(_markerEnd)) {
      return (comment: caption.trim(), news: null);
    }
    final payloadStart = markerIndex + _markerStart.length;
    final payloadEnd = caption.trimRight().length - _markerEnd.length;
    try {
      final decoded = jsonDecode(
        utf8.decode(
          base64Url.decode(caption.substring(payloadStart, payloadEnd)),
        ),
      );
      if (decoded is! Map<String, dynamic>) {
        return (comment: caption.trim(), news: null);
      }
      final title = decoded['title'] as String? ?? '';
      final articleUrl = decoded['article_url'] as String? ?? '';
      final uri = Uri.tryParse(articleUrl);
      if (title.trim().isEmpty ||
          uri == null ||
          !{'https', 'http'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        return (comment: caption.trim(), news: null);
      }
      return (
        comment: caption.substring(0, markerIndex).trim(),
        news: SharedNewsPostContent(
          title: title,
          source: decoded['source'] as String? ?? '',
          summary: decoded['summary'] as String? ?? '',
          articleUrl: articleUrl,
          imageUrl: decoded['image_url'] as String? ?? '',
          publishedLabel: decoded['published_label'] as String? ?? '',
        ),
      );
    } catch (_) {
      return (comment: caption.trim(), news: null);
    }
  }
}

enum ProfileContentType {
  post('post'),
  drop('drop'),
  fancam('fancam'),
  story('story');

  const ProfileContentType(this.key);

  final String key;

  static ProfileContentType? fromKey(String key) {
    for (final type in values) {
      if (type.key == key) return type;
    }
    return null;
  }
}

enum ProfileContentCategory {
  concerts('concerts', 'Conciertos'),
  bias('bias', 'Bias'),
  photocards('photocards', 'Photocards'),
  outfit('outfit', 'Outfit'),
  collection('collection', 'Colección'),
  trades('trades', 'Trades/Ventas'),
  merch('merch', 'Merch'),
  fanart('fanart', 'Fanart'),
  other('other', 'Otro');

  const ProfileContentCategory(this.key, this.label);

  final String key;
  final String label;

  static ProfileContentCategory? fromKey(String key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return null;
  }
}

class ContentCategoryAssignment {
  const ContentCategoryAssignment({
    required this.userId,
    required this.contentType,
    required this.contentId,
    required this.category,
    this.createdAt,
  });

  final String userId;
  final ProfileContentType contentType;
  final String contentId;
  final ProfileContentCategory category;
  final DateTime? createdAt;
}

class ContentUserTag {
  const ContentUserTag({
    required this.contentType,
    required this.contentId,
    required this.taggedUserId,
    required this.taggedBy,
    this.profile,
    this.createdAt,
  });

  final ProfileContentType contentType;
  final String contentId;
  final String taggedUserId;
  final String taggedBy;
  final CommunityProfile? profile;
  final DateTime? createdAt;

  String get displayUsername {
    final username = profile?.username.trim() ?? '';
    if (username.isEmpty) return '';
    return username.startsWith('@') ? username : '@$username';
  }
}

enum KpopEntityType {
  group('group', 'Grupo'),
  idol('idol', 'Idol'),
  artist('artist', 'Artista');

  const KpopEntityType(this.key, this.label);

  final String key;
  final String label;

  static KpopEntityType fromKey(String key) {
    for (final type in values) {
      if (type.key == key) return type;
    }
    return KpopEntityType.artist;
  }
}

class KpopEntity {
  const KpopEntity({
    required this.id,
    required this.type,
    required this.name,
    this.normalizedName = '',
    this.aliases = const [],
    this.bio = '',
    this.imageUrl = '',
    this.imageAsset = '',
    this.imageSource = '',
    this.imageLicense = '',
    this.attribution = '',
    this.fandomName = '',
    this.verified = false,
  });

  final String id;
  final KpopEntityType type;
  final String name;
  final String normalizedName;
  final List<String> aliases;
  final String bio;
  final String imageUrl;
  final String imageAsset;
  final String imageSource;
  final String imageLicense;
  final String attribution;
  final String fandomName;
  final bool verified;

  String get label => name;
  String get typeLabel => type.label;

  String get searchableText =>
      '$name $normalizedName ${aliases.join(' ')} $fandomName $typeLabel'
          .toLowerCase();
}

class ContentArtistTag {
  const ContentArtistTag({
    required this.contentType,
    required this.contentId,
    required this.entityId,
    required this.taggedBy,
    this.entity,
    this.createdAt,
  });

  final ProfileContentType contentType;
  final String contentId;
  final String entityId;
  final String taggedBy;
  final KpopEntity? entity;
  final DateTime? createdAt;
}

class PostDraft {
  const PostDraft({
    this.imageAsset = '',
    this.imageBytes,
    this.mediaPath = '',
    this.containsVideo = false,
    this.mediaScale = 1,
    this.mediaOffset = Offset.zero,
    this.mediaRotation = 0,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.videoMuted = true,
    this.mediaItems = const [],
    this.caption = '',
    this.tags = const [],
    this.location = '',
    this.elements = const [],
    this.music = '',
    this.musicAsset = '',
    this.filterIndex = 0,
    this.taggedPeople = const [],
    this.taggedUserIds = const [],
    this.taggedUsers = const [],
    this.taggedEntities = const [],
    this.artist = '',
    this.privacy = 'Todos',
    this.profileCategories = const [],
  });

  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final bool containsVideo;
  final double mediaScale;
  final Offset mediaOffset;
  final double mediaRotation;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool videoMuted;
  final List<PostMediaItem> mediaItems;
  final String caption;
  final List<String> tags;
  final String location;
  final List<StoryElement> elements;
  final String music;
  final String musicAsset;
  final int filterIndex;
  final List<String> taggedPeople;
  final List<String> taggedUserIds;
  final List<CommunityProfile> taggedUsers;
  final List<KpopEntity> taggedEntities;
  final String artist;
  final String privacy;
  final List<ProfileContentCategory> profileCategories;

  bool get hasMedia =>
      mediaItems.isNotEmpty ||
      imageBytes != null ||
      imageAsset.isNotEmpty ||
      mediaPath.isNotEmpty;

  List<PostMediaItem> get effectiveMediaItems {
    if (mediaItems.isNotEmpty) return mediaItems;
    if (imageBytes == null && imageAsset.isEmpty && mediaPath.isEmpty) {
      return const [];
    }
    return [
      PostMediaItem(
        id: 'draft-single-media',
        type: containsVideo ? PostMediaType.video : PostMediaType.image,
        imageAsset: imageAsset,
        imageBytes: imageBytes,
        mediaPath: mediaPath,
        mediaScale: mediaScale,
        mediaOffset: mediaOffset,
        mediaRotation: mediaRotation,
        videoTrimStartSeconds: videoTrimStartSeconds,
        videoTrimEndSeconds: videoTrimEndSeconds,
        videoMuted: videoMuted,
      ),
    ];
  }

  PostDraft copyWith({
    String? imageAsset,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
    String? mediaPath,
    bool? containsVideo,
    double? mediaScale,
    Offset? mediaOffset,
    double? mediaRotation,
    double? videoTrimStartSeconds,
    double? videoTrimEndSeconds,
    bool clearVideoTrimEndSeconds = false,
    bool? videoMuted,
    List<PostMediaItem>? mediaItems,
    String? caption,
    List<String>? tags,
    String? location,
    List<StoryElement>? elements,
    String? music,
    String? musicAsset,
    int? filterIndex,
    List<String>? taggedPeople,
    List<String>? taggedUserIds,
    List<CommunityProfile>? taggedUsers,
    List<KpopEntity>? taggedEntities,
    String? artist,
    String? privacy,
    List<ProfileContentCategory>? profileCategories,
  }) {
    return PostDraft(
      imageAsset: imageAsset ?? this.imageAsset,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      mediaPath: mediaPath ?? this.mediaPath,
      containsVideo: containsVideo ?? this.containsVideo,
      mediaScale: mediaScale ?? this.mediaScale,
      mediaOffset: mediaOffset ?? this.mediaOffset,
      mediaRotation: mediaRotation ?? this.mediaRotation,
      videoTrimStartSeconds:
          videoTrimStartSeconds ?? this.videoTrimStartSeconds,
      videoTrimEndSeconds: clearVideoTrimEndSeconds
          ? null
          : videoTrimEndSeconds ?? this.videoTrimEndSeconds,
      videoMuted: videoMuted ?? this.videoMuted,
      mediaItems: mediaItems ?? this.mediaItems,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      elements: elements ?? this.elements,
      music: music ?? this.music,
      musicAsset: musicAsset ?? this.musicAsset,
      filterIndex: filterIndex ?? this.filterIndex,
      taggedPeople: taggedPeople ?? this.taggedPeople,
      taggedUserIds: taggedUserIds ?? this.taggedUserIds,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      taggedEntities: taggedEntities ?? this.taggedEntities,
      artist: artist ?? this.artist,
      privacy: privacy ?? this.privacy,
      profileCategories: profileCategories ?? this.profileCategories,
    );
  }
}

class PostComment {
  const PostComment({
    this.id = '',
    this.parentId = '',
    this.authorId = '',
    required this.author,
    required this.username,
    required this.avatarAsset,
    required this.body,
    required this.time,
    this.likes = 0,
    this.replies = const [],
    this.isOwn = false,
  });

  final String id;
  final String parentId;
  final String authorId;
  final String author;
  final String username;
  final String avatarAsset;
  final String body;
  final String time;
  final int likes;
  final List<PostComment> replies;
  final bool isOwn;

  PostComment copyWith({
    String? id,
    String? parentId,
    String? authorId,
    String? author,
    String? username,
    String? avatarAsset,
    String? body,
    String? time,
    int? likes,
    List<PostComment>? replies,
    bool? isOwn,
  }) {
    return PostComment(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      username: username ?? this.username,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      body: body ?? this.body,
      time: time ?? this.time,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
      isOwn: isOwn ?? this.isOwn,
    );
  }
}

enum BetaAccessStatus { approved, waitlist, blocked }

class BetaAccessState {
  const BetaAccessState({
    required this.status,
    required this.userLimit,
    required this.approvedCount,
    this.position,
  });

  factory BetaAccessState.approved() {
    return const BetaAccessState(
      status: BetaAccessStatus.approved,
      userLimit: 100,
      approvedCount: 0,
      position: null,
    );
  }

  factory BetaAccessState.fromJson(Map<String, dynamic> json) {
    final statusText = _string(json, 'status', 'waitlist');
    final status = switch (statusText) {
      'approved' => BetaAccessStatus.approved,
      'blocked' => BetaAccessStatus.blocked,
      _ => BetaAccessStatus.waitlist,
    };
    return BetaAccessState(
      status: status,
      userLimit: _int(json, 'beta_user_limit', 100),
      approvedCount: _int(json, 'approved_count', 0),
      position: _nullableInt(json, 'position'),
    );
  }

  final BetaAccessStatus status;
  final int userLimit;
  final int approvedCount;
  final int? position;

  bool get isApproved => status == BetaAccessStatus.approved;
  bool get isWaitlisted => status == BetaAccessStatus.waitlist;
  bool get isBlocked => status == BetaAccessStatus.blocked;

  static String _string(
    Map<String, dynamic> json,
    String key,
    String fallback,
  ) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static int _int(Map<String, dynamic> json, String key, int fallback) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _nullableInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class AuthUser {
  const AuthUser({
    required this.name,
    required this.username,
    required this.email,
    required this.avatarAsset,
    required this.fandom,
    this.bio =
        'Conecto con fandoms, eventos y colecciones favoritas desde HallyuHub.',
    this.country = '',
    this.region = '',
    this.city = '',
    this.language = 'Español',
    this.phone = '',
    this.bias = '',
    this.favoriteGroup = '',
    this.phrase = 'Compartiendo mi mundo fandom.',
    this.contentRegion = '',
    this.locationVisibility = 'country',
    this.locationUpdatedAt,
    this.privateProfile = false,
    this.notificationsEnabled = true,
    this.messagePrivacy = 'Seguidores',
    this.storyPrivacy = 'Seguidores',
    this.appTheme = 'Sistema',
    this.profileBackground = 'Pastel neon',
    this.notifyMessages = true,
    this.notifyStars = true,
    this.notifyComments = true,
    this.notifyFollowers = true,
    this.notifyDrops = true,
    this.twoFactorEnabled = false,
    this.loginAlerts = true,
    this.accountVerified = false,
    this.blockedUsers = const ['@fake.ticket', '@spam.trade'],
    this.termsAcceptedAt,
    this.privacyAcceptedAt,
    this.communityGuidelinesAcceptedAt,
    this.betaNoticeAcceptedAt,
    this.legalVersion = '',
    this.role = 'user',
    this.birthDate,
    this.enforcementStatus = 'active',
    this.enforcementUntil,
  });

  final String name;
  final String username;
  final String email;
  final String avatarAsset;
  final String fandom;
  final String bio;
  final String country;
  final String region;
  final String city;
  final String language;
  final String phone;
  final String bias;
  final String favoriteGroup;
  final String phrase;
  final String contentRegion;
  final String locationVisibility;
  final DateTime? locationUpdatedAt;
  final bool privateProfile;
  final bool notificationsEnabled;
  final String messagePrivacy;
  final String storyPrivacy;
  final String appTheme;
  final String profileBackground;
  final bool notifyMessages;
  final bool notifyStars;
  final bool notifyComments;
  final bool notifyFollowers;
  final bool notifyDrops;
  final bool twoFactorEnabled;
  final bool loginAlerts;
  final bool accountVerified;
  final List<String> blockedUsers;
  final DateTime? termsAcceptedAt;
  final DateTime? privacyAcceptedAt;
  final DateTime? communityGuidelinesAcceptedAt;
  final DateTime? betaNoticeAcceptedAt;
  final String legalVersion;
  final String role;
  final DateTime? birthDate;
  final String enforcementStatus;
  final DateTime? enforcementUntil;

  int? get age => birthDate == null ? null : AgePolicy.ageAt(birthDate!);
  bool get isTeen => AgePolicy.isTeen(birthDate);
  bool get isEnforced =>
      enforcementStatus != 'active' &&
      (enforcementUntil == null || enforcementUntil!.isAfter(DateTime.now()));
  bool get canInteract => !isEnforced || enforcementStatus == 'warning';
  bool get hasRestrictedTeenPrivacy =>
      isTeen && privateProfile && messagePrivacy.toLowerCase() == 'nadie';

  bool get canAccessAdminPanel {
    final normalized = role.trim().toLowerCase();
    return normalized == 'admin' || normalized == 'moderator';
  }

  AuthUser copyWith({
    String? name,
    String? username,
    String? email,
    String? avatarAsset,
    String? fandom,
    String? bio,
    String? country,
    String? region,
    String? city,
    String? language,
    String? phone,
    String? bias,
    String? favoriteGroup,
    String? phrase,
    String? contentRegion,
    String? locationVisibility,
    DateTime? locationUpdatedAt,
    bool clearLocationUpdatedAt = false,
    bool? privateProfile,
    bool? notificationsEnabled,
    String? messagePrivacy,
    String? storyPrivacy,
    String? appTheme,
    String? profileBackground,
    bool? notifyMessages,
    bool? notifyStars,
    bool? notifyComments,
    bool? notifyFollowers,
    bool? notifyDrops,
    bool? twoFactorEnabled,
    bool? loginAlerts,
    bool? accountVerified,
    List<String>? blockedUsers,
    DateTime? termsAcceptedAt,
    DateTime? privacyAcceptedAt,
    DateTime? communityGuidelinesAcceptedAt,
    DateTime? betaNoticeAcceptedAt,
    String? legalVersion,
    String? role,
    DateTime? birthDate,
    String? enforcementStatus,
    DateTime? enforcementUntil,
  }) {
    return AuthUser(
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      fandom: fandom ?? this.fandom,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      region: region ?? this.region,
      city: city ?? this.city,
      language: language ?? this.language,
      phone: phone ?? this.phone,
      bias: bias ?? this.bias,
      favoriteGroup: favoriteGroup ?? this.favoriteGroup,
      phrase: phrase ?? this.phrase,
      contentRegion: contentRegion ?? this.contentRegion,
      locationVisibility: locationVisibility ?? this.locationVisibility,
      locationUpdatedAt: clearLocationUpdatedAt
          ? null
          : locationUpdatedAt ?? this.locationUpdatedAt,
      privateProfile: privateProfile ?? this.privateProfile,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      messagePrivacy: messagePrivacy ?? this.messagePrivacy,
      storyPrivacy: storyPrivacy ?? this.storyPrivacy,
      appTheme: appTheme ?? this.appTheme,
      profileBackground: profileBackground ?? this.profileBackground,
      notifyMessages: notifyMessages ?? this.notifyMessages,
      notifyStars: notifyStars ?? this.notifyStars,
      notifyComments: notifyComments ?? this.notifyComments,
      notifyFollowers: notifyFollowers ?? this.notifyFollowers,
      notifyDrops: notifyDrops ?? this.notifyDrops,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      loginAlerts: loginAlerts ?? this.loginAlerts,
      accountVerified: accountVerified ?? this.accountVerified,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
      communityGuidelinesAcceptedAt:
          communityGuidelinesAcceptedAt ?? this.communityGuidelinesAcceptedAt,
      betaNoticeAcceptedAt: betaNoticeAcceptedAt ?? this.betaNoticeAcceptedAt,
      legalVersion: legalVersion ?? this.legalVersion,
      role: role ?? this.role,
      birthDate: birthDate ?? this.birthDate,
      enforcementStatus: enforcementStatus ?? this.enforcementStatus,
      enforcementUntil: enforcementUntil ?? this.enforcementUntil,
    );
  }

  bool get hasAcceptedCurrentLegal {
    return legalVersion == hallyuHubLegalVersion &&
        termsAcceptedAt != null &&
        privacyAcceptedAt != null &&
        communityGuidelinesAcceptedAt != null &&
        betaNoticeAcceptedAt != null;
  }

  String get configuredLocationLabel {
    final countryText = country.trim();
    final regionText = region.trim();
    final cityText = city.trim();
    if (countryText.isEmpty && regionText.isEmpty && cityText.isEmpty) {
      return 'Ubicación no configurada';
    }
    final parts = [
      if (cityText.isNotEmpty) cityText,
      if (regionText.isNotEmpty && regionText != cityText) regionText,
      if (countryText.isNotEmpty) countryText,
    ];
    return parts.join(', ');
  }

  String get publicLocationLabel {
    final countryText = country.trim();
    final regionText = region.trim();
    final cityText = city.trim();
    switch (locationVisibility) {
      case 'hidden':
        return 'Ubicación oculta';
      case 'city':
        if (cityText.isNotEmpty && countryText.isNotEmpty) {
          return '$cityText, $countryText';
        }
        if (cityText.isNotEmpty) return cityText;
        if (regionText.isNotEmpty && countryText.isNotEmpty) {
          return '$regionText, $countryText';
        }
        if (regionText.isNotEmpty) return regionText;
        return countryText.isEmpty ? 'Ubicación no configurada' : countryText;
      case 'country':
      default:
        return countryText.isEmpty ? 'Ubicación no configurada' : countryText;
    }
  }
}

enum StoreProfileStatus {
  pending('pending', 'Pendiente'),
  active('active', 'Activa'),
  paused('paused', 'Pausada'),
  blocked('blocked', 'Bloqueada');

  const StoreProfileStatus(this.key, this.label);

  final String key;
  final String label;

  static StoreProfileStatus fromKey(String value) {
    final normalized = value.trim().toLowerCase();
    return StoreProfileStatus.values.firstWhere(
      (status) => status.key == normalized,
      orElse: () => StoreProfileStatus.pending,
    );
  }
}

class StoreProfileDraft {
  const StoreProfileDraft({
    required this.storeName,
    this.description = '',
    this.country = '',
    this.region = '',
    this.city = '',
    this.categories = const [],
    this.deliveryMethods = const [],
    this.paymentMethods = const [],
    this.contactUrl = '',
    this.instagramUrl = '',
    this.whatsappUrl = '',
    this.openingHours = '',
  });

  final String storeName;
  final String description;
  final String country;
  final String region;
  final String city;
  final List<String> categories;
  final List<String> deliveryMethods;
  final List<String> paymentMethods;
  final String contactUrl;
  final String instagramUrl;
  final String whatsappUrl;
  final String openingHours;
}

class StoreProfile {
  const StoreProfile({
    required this.id,
    required this.ownerId,
    required this.storeName,
    required this.status,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.country = '',
    this.region = '',
    this.city = '',
    this.categories = const [],
    this.deliveryMethods = const [],
    this.paymentMethods = const [],
    this.contactUrl = '',
    this.instagramUrl = '',
    this.whatsappUrl = '',
    this.openingHours = '',
    this.verifiedBy = '',
    this.verifiedAt,
    this.profileViews = 0,
    this.contactClicks = 0,
    this.owner,
  });

  final String id;
  final String ownerId;
  final String storeName;
  final String description;
  final String country;
  final String region;
  final String city;
  final List<String> categories;
  final List<String> deliveryMethods;
  final List<String> paymentMethods;
  final String contactUrl;
  final String instagramUrl;
  final String whatsappUrl;
  final String openingHours;
  final StoreProfileStatus status;
  final bool isVerified;
  final String verifiedBy;
  final DateTime? verifiedAt;
  final int profileViews;
  final int contactClicks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CommunityProfile? owner;

  bool get isActive => status == StoreProfileStatus.active;
  bool get isPaused => status == StoreProfileStatus.paused;
  bool get isPending => status == StoreProfileStatus.pending;
  bool get isBlocked => status == StoreProfileStatus.blocked;
}

class StoreProfileAdminData {
  const StoreProfileAdminData({required this.entries});

  final List<StoreProfile> entries;

  int get total => entries.length;
  int get pending => entries.where((entry) => entry.isPending).length;
  int get active => entries.where((entry) => entry.isActive).length;
  int get paused => entries.where((entry) => entry.isPaused).length;
  int get verified => entries.where((entry) => entry.isVerified).length;
}

class ArtistTrend {
  const ArtistTrend({
    required this.name,
    required this.tag,
    required this.imageAsset,
    required this.signal,
    required this.accent,
  });

  final String name;
  final String tag;
  final String imageAsset;
  final String signal;
  final Color accent;
}

class DropClip {
  const DropClip({
    this.id = '',
    required this.title,
    required this.artist,
    required this.creator,
    required this.audio,
    required this.imageAsset,
    required this.views,
    required this.likes,
    this.creatorId = '',
    this.creatorName = '',
    this.creatorAvatarAsset = '',
    this.groupId = '',
    this.artistId = '',
    this.caption = '',
    this.location = '',
    this.videoPath = '',
    this.videoDurationSeconds,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.optimizedForUpload = false,
    this.filter = 'Original',
    this.comments = '912',
    this.taggedPeople = const [],
    this.taggedUserIds = const [],
    this.taggedEntities = const [],
    this.createdAt,
    this.isOwn = false,
  });

  final String id;
  final String title;
  final String artist;
  final String creator;
  final String audio;
  final String imageAsset;
  final String views;
  final String likes;
  final String creatorId;
  final String creatorName;
  final String creatorAvatarAsset;
  final String groupId;
  final String artistId;
  final String caption;
  final String location;
  final String videoPath;
  final double? videoDurationSeconds;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool optimizedForUpload;
  final String filter;
  final String comments;
  final List<String> taggedPeople;
  final List<String> taggedUserIds;
  final List<KpopEntity> taggedEntities;
  final DateTime? createdAt;
  final bool isOwn;

  bool get hasVideo => videoPath.isNotEmpty;
}

class Fancam {
  const Fancam({
    this.id = '',
    required this.title,
    required this.artist,
    required this.creator,
    required this.imageAsset,
    required this.duration,
    required this.energy,
    this.creatorId = '',
    this.creatorName = '',
    this.creatorAvatarAsset = '',
    this.groupId = '',
    this.artistId = '',
    this.caption = '',
    this.audio = '',
    this.location = '',
    this.videoPath = '',
    this.likes = '0',
    this.comments = '0',
    this.saves = '0',
    this.shares = '0',
    this.taggedPeople = const [],
    this.taggedUserIds = const [],
    this.taggedEntities = const [],
    this.createdAt,
    this.isOwn = false,
  });

  final String id;
  final String title;
  final String artist;
  final String creator;
  final String imageAsset;
  final String duration;
  final String energy;
  final String creatorId;
  final String creatorName;
  final String creatorAvatarAsset;
  final String groupId;
  final String artistId;
  final String caption;
  final String audio;
  final String location;
  final String videoPath;
  final String likes;
  final String comments;
  final String saves;
  final String shares;
  final List<String> taggedPeople;
  final List<String> taggedUserIds;
  final List<KpopEntity> taggedEntities;
  final DateTime? createdAt;
  final bool isOwn;

  bool get hasVideo => videoPath.isNotEmpty;
}

class ProfileStat {
  const ProfileStat(this.value, this.label);

  final String value;
  final String label;
}
