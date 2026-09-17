import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../data/collection_data.dart';
import '../data/demo_data.dart';
import '../models.dart';
import '../screens/camera_capture_screen.dart';
import '../screens/drops_screen.dart';
import '../screens/fancams_screen.dart';
import '../screens/kpop_entity_profile_screen.dart';
import '../screens/messages_inbox_screen.dart';
import '../screens/post_editor_screen.dart';
import '../screens/public_profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/story_archive_screen.dart';
import '../screens/story_editor_screen.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/feedback_report_service.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/media_upload_limits.dart';
import '../services/media_permission_service.dart';
import '../services/share_links.dart';
import '../services/store_profile_service.dart';
import '../services/account_deletion_service.dart';
import '../services/beta_signup_service.dart';
import '../services/content_moderation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/contextual_permission_sheet.dart';
import '../widgets/hallyu_post_card.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/post_video_player.dart';
import '../widgets/premium_form_shell.dart';
import '../widgets/premium_profile_visuals.dart';
import '../widgets/profile_category_chips.dart';
import '../widgets/share_sheet.dart';
import '../widgets/story_composer_sheet.dart';
import '../widgets/store_profile_card.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

enum _ProfileTab {
  posts,
  drops,
  fancams,
  outfit,
  photocards,
  collection,
  trades,
  wishlist,
  saved,
  archive,
}

enum _CollectionCreateMode { collection, tradeSale, wishlist }

enum _CreateKind {
  story(
    label: 'Historia',
    title: 'Nueva historia',
    detail: 'Momento rápido para tus seguidores.',
    badge: 'Historia',
    tab: _ProfileTab.posts,
    fallbackAsset: 'assets/demo-posts/post-01.jpg',
  ),
  drop(
    label: 'Fancam / Drop',
    title: 'Nuevo Fancam / Drop',
    detail: 'Video vertical, challenge o cover.',
    badge: 'Drop',
    tab: _ProfileTab.drops,
    fallbackAsset: 'assets/demo-posts/post-03.jpg',
    isVideo: true,
  ),
  outfit(
    label: 'Outfit',
    title: 'Nuevo outfit',
    detail: 'Look de evento, dance cover o stage fit.',
    badge: 'Outfit',
    tab: _ProfileTab.outfit,
    fallbackAsset: 'assets/demo-posts/post-10.jpg',
  );

  const _CreateKind({
    required this.label,
    required this.title,
    required this.detail,
    required this.badge,
    required this.tab,
    required this.fallbackAsset,
    this.isVideo = false,
  });

  final String label;
  final String title;
  final String detail;
  final String badge;
  final _ProfileTab tab;
  final String fallbackAsset;
  final bool isVideo;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserChanged,
    required this.onPrivateProfileChanged,
    required this.onSignOut,
    this.postService = const LocalPostService(),
    this.followService = const LocalFollowService(),
    this.storyService = const LocalStoryService(),
    this.chatService = const LocalChatService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.safetyService = const LocalSafetyService(),
    this.feedbackReportService = const LocalFeedbackReportService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.accountDeletionService = const LocalAccountDeletionService(),
    this.betaSignupService = const LocalBetaSignupService(),
    this.contentModerationService = const UnavailableContentModerationService(),
    this.resetSignal = 0,
  });

  final AuthUser user;
  final Future<void> Function(AuthUser user) onUserChanged;
  final Future<void> Function(bool privateProfile) onPrivateProfileChanged;
  final VoidCallback onSignOut;
  final LocalPostService postService;
  final LocalFollowService followService;
  final LocalStoryService storyService;
  final LocalChatService chatService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalSafetyService safetyService;
  final FeedbackReportService feedbackReportService;
  final StoreProfileService storeProfileService;
  final AccountDeletionService accountDeletionService;
  final BetaSignupService betaSignupService;
  final ContentModerationService contentModerationService;
  final int resetSignal;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _ProfileTab _selectedTab = _ProfileTab.posts;
  final Set<String> _savedItems = {'post-lookbook', 'guide-stream'};
  final Set<String> _savedCollectionItems = {};
  final Set<String> _followedProfiles = {};
  FollowCounts _currentFollowCounts = const FollowCounts();
  final Set<String> _starredItems = {};
  final Set<String> _updatingPublishedStars = {};
  final Set<String> _updatingPublishedSaves = {};
  final Map<String, int> _commentAdditions = {};
  final Map<String, List<PostComment>> _commentsByActivity = {};
  final List<_ProfileActivity> _createdActivities = [];
  final MediaPermissionService _permissionService =
      const MediaPermissionService();
  final List<_ProfileActivity> _publishedPostActivities = [];
  final Map<String, HubPost> _publishedPostsByActivityId = {};
  final List<_ProfileActivity> _publishedDropActivities = [];
  final List<_ProfileActivity> _publishedFancamActivities = [];
  List<ContentCategoryAssignment> _contentCategoryAssignments = const [];
  ProfileContentCategory? _selectedContentCategory;
  final Map<String, DropClip> _profileDropsByActivityId = {};
  final Map<String, Fancam> _profileFancamsByActivityId = {};
  final List<CollectionItem> _createdCollectionItems = [];
  final List<_DemoProfile> _realProfiles = [];
  final List<_DemoProfile> _realFollowerProfiles = [];
  final List<_DemoProfile> _realFollowingProfiles = [];
  final GlobalKey _profileContentKey = GlobalKey();
  double? _profileContentScrollOffset;
  final ImagePicker _imagePicker = ImagePicker();
  final _scrollController = ScrollController();
  StoreProfile? _storeProfile;
  bool _loadingStoreProfile = false;

  AuthUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    LocalPostService.revision.addListener(_reloadPublishedPosts);
    LocalDropService.revision.addListener(_reloadPublishedVideos);
    LocalFancamService.revision.addListener(_reloadPublishedVideos);
    LocalFollowService.revision.addListener(_reloadFollowing);
    LocalContentCategoryService.revision.addListener(_reloadContentCategories);
    LocalStoreProfileService.revision.addListener(_reloadStoreProfile);
    _restorePublishedPosts();
    _restorePublishedVideos();
    _restoreFollowing();
    _restoreContentCategories();
    _restoreStoreProfile();
  }

  @override
  void dispose() {
    LocalPostService.revision.removeListener(_reloadPublishedPosts);
    LocalDropService.revision.removeListener(_reloadPublishedVideos);
    LocalFancamService.revision.removeListener(_reloadPublishedVideos);
    LocalFollowService.revision.removeListener(_reloadFollowing);
    LocalContentCategoryService.revision.removeListener(
      _reloadContentCategories,
    );
    LocalStoreProfileService.revision.removeListener(_reloadStoreProfile);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) _resetToTop();
  }

  void _resetToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _reloadPublishedPosts() {
    _restorePublishedPosts();
  }

  void _reloadPublishedVideos() {
    _restorePublishedVideos();
  }

  void _reloadFollowing() {
    _restoreFollowing();
  }

  void _reloadContentCategories() {
    _restoreContentCategories();
  }

  void _reloadStoreProfile() {
    _restoreStoreProfile();
  }

  Future<void> _restoreStoreProfile() async {
    if (_loadingStoreProfile) return;
    _loadingStoreProfile = true;
    try {
      final store = await widget.storeProfileService.restoreOwnStore();
      if (!mounted) return;
      setState(() => _storeProfile = store);
    } catch (error) {
      debugPrint('PROFILE_STORE_RESTORE_ERROR error=$error');
    } finally {
      _loadingStoreProfile = false;
    }
  }

  Future<void> _restoreContentCategories() async {
    try {
      final rows = await widget.contentCategoryService.restoreForUser(
        widget.contentCategoryService.usesRealCategories ? '' : 'local-user',
      );
      if (!mounted) return;
      setState(() => _contentCategoryAssignments = rows);
    } catch (error) {
      debugPrint('PROFILE_CATEGORY_RESTORE_ERROR ownProfile error=$error');
      if (!mounted) return;
      setState(() => _contentCategoryAssignments = const []);
    }
  }

  Future<void> _restoreFollowing() async {
    var following = <String>{};
    var counts = const FollowCounts();
    var profiles = <CommunityProfile>[];
    var followers = <CommunityProfile>[];
    var followingProfiles = <CommunityProfile>[];
    try {
      following = await widget.followService.restoreFollowingIds();
    } catch (error) {
      debugPrint('FOLLOW_LIST_ERROR ownProfile ids error=$error');
    }
    try {
      counts = await widget.followService.restoreCurrentUserCounts();
    } catch (error) {
      debugPrint('FOLLOW_LIST_ERROR ownProfile counts error=$error');
    }
    try {
      profiles = await widget.followService.restoreProfiles(limit: 120);
    } catch (error) {
      debugPrint('FOLLOW_LIST_ERROR ownProfile profiles error=$error');
    }
    try {
      followers = await widget.followService.restoreCurrentUserFollowers();
    } catch (error) {
      debugPrint('FOLLOW_LIST_ERROR ownProfile followers error=$error');
    }
    try {
      followingProfiles = await widget.followService
          .restoreCurrentUserFollowingProfiles();
    } catch (error) {
      debugPrint('FOLLOW_LIST_ERROR ownProfile following error=$error');
    }
    if (!mounted) return;
    setState(() {
      _followedProfiles
        ..clear()
        ..addAll(following);
      _currentFollowCounts = counts;
      _realProfiles
        ..clear()
        ..addAll(profiles.map(_DemoProfile.fromCommunity));
      _realFollowerProfiles
        ..clear()
        ..addAll(followers.map(_DemoProfile.fromCommunity));
      _realFollowingProfiles
        ..clear()
        ..addAll(followingProfiles.map(_DemoProfile.fromCommunity));
    });
  }

  Future<void> _restorePublishedPosts() async {
    List<HubPost> posts;
    final stopwatch = Stopwatch()..start();
    _logPerformance('PERF_PROFILE_POSTS_START username=${user.username}');
    try {
      posts = await widget.postService.restorePosts(
        onlyCurrentUser: widget.postService.usesRealPosts,
        limit: 24,
      );
    } catch (_) {
      posts = const [];
    }
    _logPerformance(
      'PERF_PROFILE_POSTS_OK count=${posts.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    if (!mounted) return;
    setState(() {
      final previousPublishedIds = _publishedPostActivities
          .map((activity) => activity.id)
          .toSet();
      _starredItems.removeAll(previousPublishedIds);
      _savedItems.removeAll(previousPublishedIds);
      _publishedPostActivities
        ..clear()
        ..addAll(
          posts.where((post) => post.isOwn).map(_activityFromPublishedPost),
        );
      _publishedPostsByActivityId
        ..clear()
        ..addEntries(
          posts
              .where((post) => post.isOwn)
              .map((post) => MapEntry(post.id, post)),
        );
      _starredItems.addAll(
        posts.where((post) => post.likedByCurrentUser).map((post) => post.id),
      );
      _savedItems.addAll(
        posts.where((post) => post.savedByCurrentUser).map((post) => post.id),
      );
    });
  }

  Future<void> _restorePublishedVideos() async {
    List<DropClip> drops;
    List<Fancam> fancams;
    final stopwatch = Stopwatch()..start();
    _logPerformance('PERF_PROFILE_VIDEOS_START username=${user.username}');
    try {
      drops = await widget.dropService.restoreDrops(
        onlyCurrentUser: widget.dropService.usesRealDrops,
        limit: 24,
      );
    } catch (error) {
      debugPrint('PROFILE_VIDEO_ERROR restoreDrops error=$error');
      drops = const [];
    }
    try {
      fancams = await widget.fancamService.restoreFancams(
        onlyCurrentUser: widget.fancamService.usesRealFancams,
        limit: 24,
      );
    } catch (error) {
      debugPrint('PROFILE_VIDEO_ERROR restoreFancams error=$error');
      fancams = const [];
    }
    _logPerformance(
      'PERF_PROFILE_VIDEOS_OK drops=${drops.length} fancams=${fancams.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    if (!mounted) return;
    final ownDrops = drops.where(_isOwnDrop).toList(growable: false);
    final ownFancams = fancams.where(_isOwnFancam).toList(growable: false);
    setState(() {
      _profileDropsByActivityId
        ..clear()
        ..addEntries(
          ownDrops.map((drop) {
            final activity = _activityFromDrop(drop);
            return MapEntry(activity.id, drop);
          }),
        );
      _profileFancamsByActivityId
        ..clear()
        ..addEntries(
          ownFancams.map((fancam) {
            final activity = _activityFromFancam(fancam);
            return MapEntry(activity.id, fancam);
          }),
        );
      _publishedDropActivities
        ..clear()
        ..addAll(ownDrops.map(_activityFromDrop));
      _publishedFancamActivities
        ..clear()
        ..addAll(ownFancams.map(_activityFromFancam));
    });
  }

  bool _isOwnDrop(DropClip drop) {
    if (drop.isOwn) return true;
    final username = _normalizeUsername(drop.creator);
    return username.isNotEmpty && username == _normalizeUsername(user.username);
  }

  bool _isOwnFancam(Fancam fancam) {
    if (fancam.isOwn) return true;
    final username = _normalizeUsername(fancam.creator);
    return username.isNotEmpty && username == _normalizeUsername(user.username);
  }

  String _normalizeUsername(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');

  String _dropId(DropClip drop) {
    if (drop.id.isNotEmpty) return drop.id;
    return drop.title.toLowerCase().replaceAll(' ', '-');
  }

  String _fancamKey(Fancam fancam) {
    if (fancam.id.isNotEmpty) return fancam.id;
    return '${fancam.creatorId}-${fancam.artistId}-${fancam.title}';
  }

  _ProfileActivity _activityFromDrop(DropClip drop) {
    final id = 'drop-${drop.id.isEmpty ? drop.title : drop.id}';
    final duration = _dropDurationLabel(drop);
    return _ProfileActivity(
      id: id,
      tab: _ProfileTab.drops,
      contentType: ProfileContentType.drop,
      contentId: _dropId(drop),
      profileId: 'local-user',
      title: drop.caption.trim().isEmpty ? drop.title : drop.caption,
      subtitle: [
        if (drop.artist.trim().isNotEmpty) drop.artist.trim(),
        if (duration.isNotEmpty) duration,
      ].join(' · '),
      time: duration.isEmpty ? 'Video' : duration,
      detail: drop.caption.trim().isEmpty ? drop.title : drop.caption,
      imageAsset: drop.imageAsset,
      mediaPath: drop.videoPath,
      containsVideo: drop.hasVideo,
      badge: 'Ver Drop',
      tags: [
        '#Drop',
        if (drop.artist.trim().isNotEmpty)
          '#${drop.artist.trim().replaceAll(' ', '')}',
      ],
      stars: drop.likes,
      comments: drop.comments,
    );
  }

  _ProfileActivity _activityFromFancam(Fancam fancam) {
    final id = 'fancam-${fancam.id.isEmpty ? fancam.title : fancam.id}';
    return _ProfileActivity(
      id: id,
      tab: _ProfileTab.fancams,
      contentType: ProfileContentType.fancam,
      contentId: _fancamKey(fancam),
      profileId: 'local-user',
      title: fancam.caption.trim().isEmpty ? fancam.title : fancam.caption,
      subtitle: [
        if (fancam.artist.trim().isNotEmpty) fancam.artist.trim(),
        if (fancam.duration.trim().isNotEmpty) fancam.duration.trim(),
      ].join(' · '),
      time: fancam.duration.trim().isEmpty ? 'Video' : fancam.duration,
      detail: fancam.caption.trim().isEmpty ? fancam.title : fancam.caption,
      imageAsset: fancam.imageAsset,
      mediaPath: fancam.videoPath,
      containsVideo: fancam.hasVideo,
      badge: 'Ver Fancam',
      tags: [
        '#Fancam',
        if (fancam.artist.trim().isNotEmpty)
          '#${fancam.artist.trim().replaceAll(' ', '')}',
      ],
      stars: fancam.likes,
      comments: fancam.comments,
    );
  }

  String _dropDurationLabel(DropClip drop) {
    final seconds = drop.videoDurationSeconds?.round();
    if (seconds == null || seconds <= 0) return '';
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  _ProfileActivity _activityFromPublishedPost(HubPost post) {
    final location = post.location.trim().isEmpty ? 'HallyuHub' : post.location;
    return _ProfileActivity(
      id: post.id,
      tab: _ProfileTab.posts,
      contentType: ProfileContentType.post,
      contentId: post.id,
      profileId: post.authorId.isEmpty ? 'local-user' : post.authorId,
      title: 'Publicación de ${post.author}',
      subtitle: '$location · ${_postTimeLabel(post)}',
      time: post.time,
      detail: post.caption,
      imageAsset: post.imageAsset,
      imageBytes: post.imageBytes,
      mediaPath: post.mediaPath,
      mediaItems: post.effectiveMediaItems,
      containsVideo: post.containsVideo,
      badge: post.hasCarousel
          ? '${post.effectiveMediaItems.length} fotos'
          : post.hasVideoMedia
          ? 'Video'
          : 'Post',
      tags: post.tags,
      stars: post.likes,
      comments: post.comments,
      starredByCurrentUser: post.likedByCurrentUser,
      savedByCurrentUser: post.savedByCurrentUser,
    );
  }

  String _postTimeLabel(HubPost post) {
    final createdAt = post.createdAt;
    if (createdAt == null) return post.time;
    return _profileDateLabel(createdAt);
  }

  String _profileDateLabel(DateTime createdAt) {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      final diff = now.difference(local);
      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
      return 'Hace ${diff.inHours} h';
    }
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
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  void _openSettings({String? initialPanel}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AccountSettingsScreen(
          user: user,
          onUserChanged: widget.onUserChanged,
          onPrivateProfileChanged: widget.onPrivateProfileChanged,
          onSignOut: widget.onSignOut,
          initialPanel: initialPanel,
          feedbackReportService: widget.feedbackReportService,
          storeProfileService: widget.storeProfileService,
          accountDeletionService: widget.accountDeletionService,
          betaSignupService: widget.betaSignupService,
          artistTagService: widget.artistTagService,
          contentModerationService: widget.contentModerationService,
        ),
      ),
    );
  }

  void _openKpopEntity(KpopEntity entity) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => KpopEntityProfileScreen(
          entity: entity,
          currentUser: widget.user,
          artistTagService: widget.artistTagService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          followService: widget.followService,
          chatService: widget.chatService,
          contentCategoryService: widget.contentCategoryService,
          userTagService: widget.userTagService,
        ),
      ),
    );
  }

  void _openStoryArchive() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (context) => const StoryArchiveScreen()),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  void _showUploadStatus(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(minutes: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Text(message),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  String _countWithDelta(String value, int delta) {
    if (delta == 0) return value;
    if (value.toLowerCase().contains('k')) return '$value+';
    final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return '${parsed + delta}';
  }

  List<_ProfileActivity> get _allActivities => [
    ..._publishedPostActivities,
    ..._publishedDropActivities,
    ..._publishedFancamActivities,
    ..._createdActivities,
    ..._profileActivities(user),
  ];

  Map<ProfileContentCategory, int> get _profileCategoryCounts {
    return {
      for (final category in ProfileContentCategory.values)
        category: _activitiesForProfileCategory(category).length,
    };
  }

  List<_ProfileActivity> _activitiesForProfileCategory(
    ProfileContentCategory category,
  ) {
    final keys = _contentCategoryAssignments
        .where((row) => row.category == category)
        .map((row) => '${row.contentType.key}:${row.contentId}')
        .toSet();
    if (keys.isEmpty) {
      if (!widget.contentCategoryService.usesRealCategories &&
          category == ProfileContentCategory.outfit) {
        return _activitiesFor(_ProfileTab.outfit);
      }
      return const [];
    }
    return _allActivities
        .where((activity) {
          final contentType = activity.contentType;
          final contentId = activity.contentId.isEmpty
              ? activity.id
              : activity.contentId;
          if (contentType == null || contentId.isEmpty) return false;
          return keys.contains('${contentType.key}:$contentId');
        })
        .toList(growable: false);
  }

  List<CollectionItem> get _allCollectionItems {
    if (widget.followService.usesRealProfiles ||
        widget.postService.usesRealPosts) {
      return _createdCollectionItems;
    }
    final localItems = demoCollectionItems.map((item) {
      if (item.ownerId != 'local-user') return item;
      return item.copyWith(
        ownerName: user.name,
        ownerUsername: user.username,
        ownerAvatarAsset: user.avatarAsset,
        city: user.city.isNotEmpty ? user.city : user.region,
        country: user.country,
      );
    });
    return [..._createdCollectionItems, ...localItems];
  }

  List<CollectionItem> get _ownCollectionItems {
    return _allCollectionItems
        .where(
          (item) =>
              item.ownerId == 'local-user' &&
              !item.isTrade &&
              !item.isSale &&
              !item.isWishlist,
        )
        .toList(growable: false);
  }

  List<CollectionItem> get _tradeSaleItems {
    return _allCollectionItems
        .where((item) => item.isTrade || item.isSale)
        .toList(growable: false);
  }

  List<CollectionItem> get _wishlistItems {
    return _allCollectionItems
        .where((item) => item.isWishlist)
        .toList(growable: false);
  }

  // ignore: unused_element
  List<CollectionItem> _publicCollectionForOwner(String ownerId) {
    return _allCollectionItems
        .where((item) => item.ownerId == ownerId && item.isPublic)
        .toList(growable: false);
  }

  Iterable<_ProfileActivity> get _ownActivities {
    return _allActivities.where((activity) => !activity.sharedByCommunity);
  }

  List<_DemoProfile> get _ownFollowingProfiles {
    if (widget.followService.usesRealProfiles) return _realFollowingProfiles;
    final source =
        widget.followService.usesRealProfiles && _realProfiles.isNotEmpty
        ? _realProfiles
        : _communityProfiles;
    return source
        .where((profile) => _followedProfiles.contains(profile.id))
        .toList(growable: false);
  }

  List<_DemoProfile> get _ownFollowerProfiles {
    if (widget.followService.usesRealProfiles) return _realFollowerProfiles;
    return _isDemoProfile(user) ? _followersFor(null) : [];
  }

  List<_DemoProfile> get _shareContactProfiles {
    final contacts = <String, _DemoProfile>{};
    for (final profile in _ownFollowerProfiles) {
      contacts[profile.id] = profile;
    }
    for (final profile in _ownFollowingProfiles) {
      contacts[profile.id] = profile;
    }
    return contacts.values.toList(growable: false);
  }

  int get _receivedStars {
    return _ownActivities.fold(
      0,
      (total, activity) => total + _parseCompactCount(activity.stars),
    );
  }

  List<ProfileStat> get _currentProfileStats {
    final posts = _ownActivities
        .where((activity) => activity.tab == _ProfileTab.posts)
        .length;
    return [
      ProfileStat(
        widget.followService.usesRealProfiles
            ? _formatCompactCount(_currentFollowCounts.followers)
            : '${_ownFollowerProfiles.length}',
        'seguidores',
      ),
      ProfileStat(
        widget.followService.usesRealProfiles
            ? _formatCompactCount(_currentFollowCounts.following)
            : '${_followedProfiles.length}',
        'siguiendo',
      ),
      ProfileStat('$posts', 'posts'),
      ProfileStat(_formatCompactCount(_receivedStars), 'estrellas'),
    ];
  }

  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileActionSheet(
        title: 'Crear en HallyuHub',
        subtitle: 'Elegí qué vas a publicar desde tu perfil.',
        actions: [
          _SheetAction(
            icon: Icons.edit_note,
            title: 'Publicación',
            detail: 'Post con foto, texto y tags fandom.',
            onTap: () => _openPostEditor(context),
          ),
          _SheetAction(
            icon: Icons.auto_stories_outlined,
            title: 'Historia',
            detail: 'Momento rápido para tus seguidores.',
            onTap: () => _openStoryCreator(context),
          ),
          _SheetAction(
            icon: Icons.videocam_outlined,
            title: 'Fancam / Drop',
            detail: 'Video vertical, challenge o cover.',
            onTap: () => _openMediaSourceSheet(context, _CreateKind.drop),
          ),
          _SheetAction(
            icon: Icons.collections_bookmark_outlined,
            title: 'Agregar a colección',
            detail: 'Photocard, álbum, lightstick o merch.',
            onTap: () => _openCollectionEditor(
              context,
              _CollectionCreateMode.collection,
            ),
          ),
          _SheetAction(
            icon: Icons.swap_horiz_rounded,
            title: 'Publicar trade/venta',
            detail: 'Intercambio o consulta sin pagos en app.',
            onTap: () =>
                _openCollectionEditor(context, _CollectionCreateMode.tradeSale),
          ),
          _SheetAction(
            icon: Icons.favorite_border_rounded,
            title: 'Agregar a wishlist',
            detail: 'Mostrá lo que estás buscando.',
            onTap: () =>
                _openCollectionEditor(context, _CollectionCreateMode.wishlist),
          ),
          _SheetAction(
            icon: Icons.checkroom_outlined,
            title: 'Outfit',
            detail: 'Post de look con foto, texto y categoría Outfit.',
            onTap: () => _openPostEditor(
              context,
              initialDraft: const PostDraft(
                tags: ['#Outfit'],
                profileCategories: [ProfileContentCategory.outfit],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPostEditor(
    BuildContext sheetContext, {
    PostDraft initialDraft = const PostDraft(),
  }) async {
    Navigator.of(sheetContext).pop();
    final draft = await Navigator.of(context).push<PostDraft>(
      MaterialPageRoute<PostDraft>(
        fullscreenDialog: true,
        builder: (context) => PostEditorScreen(
          initialDraft: initialDraft,
          currentUser: widget.user,
          followService: widget.followService,
          artistTagService: widget.artistTagService,
          allowDemoMedia: !widget.postService.usesRealPosts,
        ),
      ),
    );
    if (!mounted || draft == null) return;
    _showUploadStatus('Publicando...');
    HubPost post;
    try {
      post = await widget.postService.publish(author: user, draft: draft);
    } on PostServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack('No pudimos publicar. Revisá conexión y permisos.');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final categoriesSaved = await _saveProfileCategories(
      userId: post.authorId,
      contentType: ProfileContentType.post,
      contentId: post.id,
      categories: draft.profileCategories,
    );
    if (!mounted) return;
    setState(() {
      _publishedPostsByActivityId[post.id] = post;
      _publishedPostActivities.removeWhere(
        (activity) => activity.id == post.id,
      );
      _publishedPostActivities.insert(0, _activityFromPublishedPost(post));
      _selectedTab = _ProfileTab.posts;
    });
    await _saveUserTags(
      contentType: ProfileContentType.post,
      contentId: post.id,
      taggedUsers: draft.taggedUsers,
    );
    await _saveArtistTags(
      contentType: ProfileContentType.post,
      contentId: post.id,
      taggedEntities: draft.taggedEntities,
    );
    if (!mounted) return;
    if (categoriesSaved) {
      _showSnack('Publicación agregada a tu perfil y a Inicio');
    }
  }

  Future<bool> _saveProfileCategories({
    required String userId,
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<ProfileContentCategory> categories,
  }) async {
    if (categories.isEmpty) return true;
    try {
      await widget.contentCategoryService.saveContentCategories(
        userId: userId,
        contentType: contentType,
        contentId: contentId,
        categories: categories,
      );
    } catch (error) {
      debugPrint('PROFILE_CATEGORY_SAVE_ERROR ownProfile error=$error');
      if (!mounted) return false;
      _showSnack('Publicado. No pudimos guardarlo en los globitos.');
      return false;
    }
    return true;
  }

  Future<void> _saveUserTags({
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<CommunityProfile> taggedUsers,
  }) async {
    if (taggedUsers.isEmpty) return;
    try {
      await widget.userTagService.saveContentUserTags(
        contentType: contentType,
        contentId: contentId,
        taggedUsers: taggedUsers,
      );
    } catch (error) {
      debugPrint(
        'CONTENT_USER_TAGS_SAVE_ERROR profile $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack('Publicado. No pudimos guardar todas las etiquetas.');
    }
  }

  Future<void> _saveArtistTags({
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<KpopEntity> taggedEntities,
  }) async {
    if (taggedEntities.isEmpty) return;
    try {
      await widget.artistTagService.saveContentArtistTags(
        contentType: contentType,
        contentId: contentId,
        entities: taggedEntities,
      );
    } catch (error) {
      debugPrint(
        'CONTENT_ARTIST_TAGS_SAVE_ERROR profile $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack('Publicado. No pudimos guardar artistas etiquetados.');
    }
  }

  void _openStoryCreator(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (composerContext) => StoryComposerSheet(
        templates: storyTemplates,
        onPublish: (draft) => _openStoryEditorFromSheet(composerContext, draft),
        onCamera: () =>
            _pickStoryEditorSource(composerContext, ImageSource.camera),
        onGallery: () =>
            _pickStoryEditorSource(composerContext, ImageSource.gallery),
      ),
    );
  }

  Future<void> _openStoryEditorFromSheet(
    BuildContext sheetContext,
    StoryDraft draft,
  ) async {
    Navigator.of(sheetContext).pop();
    await _openStoryEditor(draft);
  }

  Future<void> _openStoryEditor(StoryDraft draft) async {
    final edited = await Navigator.of(context).push<StoryDraft>(
      MaterialPageRoute<StoryDraft>(
        fullscreenDialog: true,
        builder: (context) => StoryEditorScreen(
          initialDraft: draft,
          currentUser: widget.user,
          followService: widget.followService,
          artistTagService: widget.artistTagService,
          supportsAdvancedAudiences: !widget.storyService.usesRealStories,
        ),
      ),
    );
    if (!mounted || edited == null) return;
    await _publishStoryDraft(edited);
  }

  Future<void> _publishStoryDraft(StoryDraft draft) async {
    _showUploadStatus('Publicando historia...');
    Story story;
    try {
      story = await widget.storyService.publish(
        author: user,
        draft: draft,
        viewers: widget.storyService.usesRealStories
            ? const []
            : demoStoryViewers,
        views: widget.storyService.usesRealStories ? 0 : 37,
        stars: widget.storyService.usesRealStories
            ? 0
            : demoStoryViewers.where((viewer) => viewer.starred).length,
      );
      if (!widget.storyService.usesRealStories) {
        await widget.chatService.addDemoIncomingStoryReply(
          story: story,
          sender: demoProfileById('demo-cami'),
        );
      }
    } on StoryServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      debugPrint('STORY_PUBLISH_ERROR ${error.message}');
      _showSnack(error.message);
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      debugPrint('STORY_PUBLISH_ERROR $error');
      _showSnack('No pudimos publicar la historia. Probá de nuevo.');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!widget.storyService.usesRealStories) {
      setState(() => _selectedTab = _ProfileTab.archive);
    }
    await _saveUserTags(
      contentType: ProfileContentType.story,
      contentId: story.id,
      taggedUsers: draft.taggedUsers,
    );
    await _saveArtistTags(
      contentType: ProfileContentType.story,
      contentId: story.id,
      taggedEntities: draft.taggedEntities,
    );
    if (!mounted) return;
    _showSnack('Historia publicada en Tu historia');
  }

  Future<void> _pickStoryEditorSource(
    BuildContext sheetContext,
    ImageSource source,
  ) async {
    Navigator.of(sheetContext).pop();
    final file = source == ImageSource.camera
        ? await Navigator.of(context).push<XFile>(
            MaterialPageRoute<XFile>(
              fullscreenDialog: true,
              builder: (context) => CameraCaptureScreen(
                recordVideo: false,
                unifiedCapture: true,
                onGallery: _pickStoryGalleryFile,
              ),
            ),
          )
        : await _pickStoryGalleryFile();
    if (!mounted) return;
    if (file == null) {
      _showSnack('No seleccionaste ninguna imagen');
      return;
    }
    final isVideo =
        file.mimeType?.startsWith('video/') == true ||
        RegExp(
          r'\.(mp4|mov|m4v|webm)$',
          caseSensitive: false,
        ).hasMatch(file.path);
    final bytes = isVideo ? null : await file.readAsBytes();
    if (!mounted) return;
    await _openStoryEditor(
      StoryDraft(
        type: isVideo ? StoryContentType.video : StoryContentType.image,
        imageBytes: bytes,
        mediaPath: file.path,
        title: 'Mi nueva historia',
        videoTrimEndSeconds: isVideo ? 60 : null,
      ),
    );
  }

  Future<XFile?> _pickStoryGalleryFile() async {
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: Icons.photo_library_outlined,
      title: 'Elegir desde tu galería',
      detail:
          'HallyuHub necesita acceso únicamente para que selecciones la foto o video de tu historia.',
      allowLabel: 'Permitir galería',
      currentStatus: _permissionService.galleryStatus,
      request: _permissionService.requestGalleryAccess,
    );
    if (!allowed || !mounted) return null;
    return _imagePicker.pickMedia(imageQuality: 86, maxWidth: 1440);
  }

  Future<void> _changeProfilePhoto() async {
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: Icons.photo_library_outlined,
      title: 'Cambiar foto de perfil',
      detail:
          'Elegí una imagen de tu galería para usarla como avatar en tu perfil, historias y publicaciones nuevas.',
      allowLabel: 'Permitir galería',
      currentStatus: _permissionService.galleryStatus,
      request: _permissionService.requestGalleryAccess,
    );
    if (!allowed || !mounted) return;
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 900,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      _showSnack('No pudimos leer la foto de perfil.');
      return;
    }
    if (bytes.lengthInBytes > MediaUploadLimits.avatarBytes) {
      _showSnack('La foto de perfil supera el límite de 5 MB.');
      return;
    }
    final detectedType = MediaUploadLimits.detectImageContentType(bytes);
    if (detectedType == null) {
      _showSnack('La foto de perfil debe ser JPG, PNG o WEBP.');
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (previewContext) => _AvatarPreviewSheet(
        bytes: bytes,
        onCancel: () => Navigator.of(previewContext).pop(false),
        onSave: () => Navigator.of(previewContext).pop(true),
      ),
    );
    if (!mounted || confirmed != true) return;
    final nextUser = user.copyWith(
      avatarAsset: 'data:$detectedType;base64,${base64Encode(bytes)}',
    );
    await widget.onUserChanged(nextUser);
    await widget.postService.updateAuthorProfile(nextUser);
    await widget.storyService.updateOwnStoryProfile(nextUser);
    if (!mounted) return;
    _showSnack('Foto de perfil actualizada');
  }

  Future<Uint8List?> _pickCollectionImage() async {
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: Icons.photo_library_outlined,
      title: 'Foto del item',
      detail:
          'HallyuHub necesita acceso a galería solo para que puedas elegir la foto de tu colección, trade o wishlist.',
      allowLabel: 'Permitir galería',
      currentStatus: _permissionService.galleryStatus,
      request: _permissionService.requestGalleryAccess,
    );
    if (!allowed || !mounted) return null;
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1440,
    );
    return file?.readAsBytes();
  }

  void _openCollectionEditor(
    BuildContext sheetContext,
    _CollectionCreateMode mode, {
    bool closeSource = true,
  }) {
    if (closeSource) Navigator.of(sheetContext).pop();
    showModalBottomSheet<CollectionItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (editorContext) => _CollectionEditorSheet(
        mode: mode,
        user: user,
        onPickImage: _pickCollectionImage,
      ),
    ).then((item) {
      if (!mounted || item == null) return;
      setState(() {
        _createdCollectionItems.insert(0, item);
        _selectedTab = item.isWishlist
            ? _ProfileTab.wishlist
            : item.isTrade || item.isSale
            ? _ProfileTab.trades
            : _ProfileTab.collection;
      });
      _showSnack('${item.title} guardado en tu perfil');
    });
  }

  void _openMediaSourceSheet(BuildContext sheetContext, _CreateKind kind) {
    Navigator.of(sheetContext).pop();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sourceContext) => _ProfileActionSheet(
        title: 'Crear ${kind.label.toLowerCase()}',
        subtitle: kind.isVideo
            ? 'Grabá un video o elegí uno que ya tengas.'
            : 'Sacá una foto o elegí una de tu galería.',
        actions: [
          _SheetAction(
            key: const ValueKey('create-source-camera'),
            icon: Icons.photo_camera_outlined,
            title: 'Abrir cámara',
            detail: kind.isVideo
                ? 'Grabar un video nuevo.'
                : 'Sacar una foto ahora.',
            onTap: () => _pickMedia(sourceContext, kind, ImageSource.camera),
          ),
          _SheetAction(
            key: const ValueKey('create-source-gallery'),
            icon: Icons.photo_library_outlined,
            title: 'Elegir de la galería',
            detail: kind.isVideo
                ? 'Subir un video guardado.'
                : 'Subir una foto guardada.',
            onTap: () => _pickMedia(sourceContext, kind, ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(
    BuildContext sheetContext,
    _CreateKind kind,
    ImageSource source,
  ) async {
    Navigator.of(sheetContext).pop();
    if (source == ImageSource.gallery) {
      final allowed = await requestContextualPermission(
        context: context,
        permissionService: _permissionService,
        icon: Icons.photo_library_outlined,
        title: 'Elegir desde tu galería',
        detail:
            'HallyuHub necesita acceso únicamente para que selecciones el contenido que querés publicar.',
        allowLabel: 'Permitir galería',
        currentStatus: _permissionService.galleryStatus,
        request: _permissionService.requestGalleryAccess,
      );
      if (!allowed || !mounted) return;
    }
    final file = source == ImageSource.camera
        ? await Navigator.of(context).push<XFile>(
            MaterialPageRoute<XFile>(
              fullscreenDialog: true,
              builder: (context) => CameraCaptureScreen(
                recordVideo: kind.isVideo,
                unifiedCapture: kind == _CreateKind.story,
              ),
            ),
          )
        : kind.isVideo
        ? await _imagePicker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 1),
          )
        : await _imagePicker.pickImage(
            source: source,
            imageQuality: 86,
            maxWidth: 1440,
          );
    if (!mounted) return;
    if (file == null) {
      _showSnack('No seleccionaste ningún archivo');
      return;
    }

    final bytes = kind.isVideo ? null : await file.readAsBytes();
    if (!mounted) return;
    if (kind == _CreateKind.outfit) {
      await _publishPickedOutfit(file: file, bytes: bytes);
      return;
    }
    final activity = _ProfileActivity(
      id: 'created-${DateTime.now().microsecondsSinceEpoch}',
      tab: kind.tab,
      profileId: 'local-user',
      title: kind.title,
      subtitle: '${kind.label} publicada · ahora',
      time: 'Ahora',
      detail: kind.detail,
      imageAsset: kind.fallbackAsset,
      imageBytes: bytes,
      containsVideo: kind.isVideo,
      badge: kind.badge,
      tags: ['#HallyuHub', '#${kind.badge.replaceAll(' ', '')}'],
      stars: '0',
      comments: '0',
    );
    setState(() {
      _createdActivities.insert(0, activity);
      _selectedTab = kind.tab;
    });
    _showSnack('${kind.label} publicada en tu perfil');
  }

  Future<void> _publishPickedOutfit({
    required XFile file,
    required Uint8List? bytes,
  }) async {
    final imageBytes = bytes ?? await file.readAsBytes();
    if (!mounted) return;
    final fileName = file.name.isEmpty
        ? 'outfit-${DateTime.now().millisecondsSinceEpoch}.jpg'
        : file.name;
    final mimeType = file.mimeType?.startsWith('image/') == true
        ? file.mimeType!
        : 'image/jpeg';
    final draft = PostDraft(
      caption: 'Outfit de ${user.name}',
      tags: const ['#HallyuHub', '#Outfit'],
      privacy: 'Todos',
      profileCategories: const [ProfileContentCategory.outfit],
      mediaItems: [
        PostMediaItem(
          id: 'outfit-media-${DateTime.now().microsecondsSinceEpoch}',
          type: PostMediaType.image,
          imageBytes: imageBytes,
          mediaPath: file.path,
          fileName: fileName,
          mimeType: mimeType,
          fileSizeBytes: imageBytes.lengthInBytes,
        ),
      ],
    );
    _showUploadStatus('Publicando outfit...');
    HubPost post;
    try {
      post = await widget.postService.publish(author: user, draft: draft);
    } on PostServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(error.message);
      return;
    } catch (error) {
      debugPrint('OUTFIT_PUBLISH_ERROR error=$error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack('No pudimos publicar el outfit. Revisá conexión y permisos.');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final categoriesSaved = await _saveProfileCategories(
      userId: post.authorId,
      contentType: ProfileContentType.post,
      contentId: post.id,
      categories: draft.profileCategories,
    );
    if (!mounted) return;
    setState(() {
      _publishedPostsByActivityId[post.id] = post;
      _publishedPostActivities.removeWhere(
        (activity) => activity.id == post.id,
      );
      _publishedPostActivities.insert(0, _activityFromPublishedPost(post));
      _selectedContentCategory = ProfileContentCategory.outfit;
      _selectedTab = _ProfileTab.posts;
    });
    if (categoriesSaved) {
      _showSnack('Outfit publicado y guardado en tu perfil.');
    }
  }

  void _openShareSheet({
    String title = 'Compartir perfil',
    String? subtitle,
    String? shareText,
  }) {
    final resolvedShareText =
        shareText ??
        'Mira el perfil de ${user.name} en HallyuHub: '
            '${ShareLinks.profile(user.username)}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => AppShareSheet(
        title: title,
        subtitle: subtitle ?? '${user.name} · ${user.username}',
        shareText: resolvedShareText,
        recipients: _shareRecipientsFor(_shareContactProfiles),
        onSendToRecipient: (recipient) =>
            _sendShareToRecipient(recipient, resolvedShareText),
        onSelected: (label) {
          Navigator.of(sheetContext).pop();
          _showSnack(label);
        },
      ),
    );
  }

  Future<String> _sendShareToRecipient(
    ShareRecipient recipient,
    String shareText,
  ) async {
    try {
      await widget.chatService.sendDirectMessage(
        conversation: DirectConversation(
          profileId: recipient.id,
          name: recipient.name,
          username: recipient.username,
          avatarAsset: recipient.avatarAsset,
          messages: const [],
        ),
        body: shareText,
      );
      return 'Compartido con ${recipient.name}';
    } catch (error) {
      debugPrint(
        'PROFILE_SHARE_DM_ERROR recipient=${recipient.id} error=$error',
      );
      return 'No pudimos enviar el mensaje a ${recipient.name}.';
    }
  }

  void _completeSheetAction(BuildContext sheetContext, String message) {
    Navigator.of(sheetContext).pop();
    _showSnack(message);
  }

  void _selectContent(_ProfileTab tab, String message) {
    setState(() => _selectedTab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contentContext = _profileContentKey.currentContext;
      if (contentContext != null) {
        Scrollable.ensureVisible(
          contentContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
    _showSnack(message);
  }

  void _focusProfileTab(_ProfileTab tab) {
    setState(() {
      _selectedContentCategory = null;
      _selectedTab = tab;
    });
    _scrollToProfileContent();
  }

  void _focusProfileCategory(ProfileContentCategory category) {
    setState(() => _selectedContentCategory = category);
    _scrollToProfileContent();
  }

  void _scrollToProfileContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contentContext = _profileContentKey.currentContext;
      final renderObject = contentContext?.findRenderObject();
      final viewport = renderObject == null
          ? null
          : RenderAbstractViewport.maybeOf(renderObject);
      final revealedOffset = renderObject == null || viewport == null
          ? null
          : viewport.getOffsetToReveal(renderObject, 0.08).offset;
      final targetOffset = (revealedOffset ?? _profileContentScrollOffset)
          ?.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          )
          .toDouble();
      if (targetOffset == null) return;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _rememberProfileContentOffset(BuildContext anchorContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final renderObject = anchorContext.findRenderObject();
      final viewport = renderObject == null
          ? null
          : RenderAbstractViewport.maybeOf(renderObject);
      if (renderObject == null || viewport == null) return;
      _profileContentScrollOffset = viewport
          .getOffsetToReveal(renderObject, 0.08)
          .offset
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          )
          .toDouble();
    });
  }

  void _openProfileInterest(String label, {String? profileName}) {
    final ownerName = profileName ?? user.name;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProfileActionSheet(
        title: label,
        subtitle: 'Información destacada de $ownerName',
        actions: [
          _SheetAction(
            icon: Icons.grid_view_rounded,
            title: 'Ver publicaciones relacionadas',
            detail: 'Explorar contenido del perfil vinculado con $label.',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _selectContent(
                _ProfileTab.posts,
                'Contenido relacionado con $label',
              );
            },
          ),
          _SheetAction(
            icon: Icons.bookmark_border_rounded,
            title: 'Guardar interés',
            detail: 'Agregar $label a tus accesos rápidos.',
            onTap: () => _completeSheetAction(
              sheetContext,
              '$label guardado en tus intereses',
            ),
          ),
        ],
      ),
    );
  }

  void _openOwnStat(String label) {
    switch (label) {
      case 'posts':
        _selectContent(_ProfileTab.posts, 'Tus publicaciones');
      case 'seguidores':
        _openConnections(
          title: 'Seguidores de ${user.name}',
          subtitle: 'Personas que siguen este perfil',
          profiles: _ownFollowerProfiles,
        );
      case 'siguiendo':
        _openConnections(
          title: 'Siguiendo',
          subtitle: 'Perfiles que sigue ${user.name}',
          profiles: _ownFollowingProfiles,
        );
      case 'estrellas':
        _openProfileInterest('Estrellas');
    }
  }

  // ignore: unused_element
  void _openPersonStat(_DemoProfile profile, String label) {
    switch (label) {
      case 'posts':
        _openPersonPosts(profile);
      case 'seguidores':
        _openConnections(
          title: 'Seguidores de ${profile.name}',
          subtitle: 'Personas que siguen este perfil',
          profiles: _followersFor(profile),
        );
      case 'siguiendo':
        _openConnections(
          title: '${profile.name} sigue a',
          subtitle: 'Perfiles visibles para la comunidad',
          profiles: _followingFor(profile),
        );
      case 'estrellas':
        _openProfileInterest('Estrellas', profileName: profile.name);
    }
  }

  void _openConnections({
    required String title,
    required String subtitle,
    required List<_DemoProfile> profiles,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ConnectionsSheet(
        title: title,
        subtitle: subtitle,
        profiles: profiles,
        followedProfiles: _followedProfiles,
        onOpen: (profile) {
          Navigator.of(sheetContext).pop();
          _openPersonProfile(profile);
        },
        onFollow: _toggleFollow,
      ),
    );
  }

  void _openPersonPosts(_DemoProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _PersonPostsSheet(
        profile: profile,
        activities: _profileActivities(
          user,
        ).where((activity) => activity.profileId == profile.id).toList(),
        onShare: (activity) {
          Navigator.of(sheetContext).pop();
          _openShareSheet(
            title: 'Compartir publicación',
            subtitle: '${activity.title} · ${profile.name}',
            shareText:
                '${activity.title}\n'
                '${ShareLinks.publication(activity.id)}',
          );
        },
      ),
    );
  }

  void _openActivityDetail(_ProfileActivity activity) {
    final drop = _profileDropsByActivityId[activity.id];
    if (drop != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => DropsScreen(
            user: widget.user,
            dropService: widget.dropService,
            followService: widget.followService,
            postService: widget.postService,
            chatService: widget.chatService,
            storyService: widget.storyService,
            fancamService: widget.fancamService,
            contentCategoryService: widget.contentCategoryService,
            userTagService: widget.userTagService,
            artistTagService: widget.artistTagService,
            safetyService: widget.safetyService,
            storeProfileService: widget.storeProfileService,
            initialDropId: _dropId(drop),
            showBackButton: true,
          ),
        ),
      );
      return;
    }
    final fancam = _profileFancamsByActivityId[activity.id];
    if (fancam != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => FancamsScreen(
            user: widget.user,
            fancamService: widget.fancamService,
            followService: widget.followService,
            postService: widget.postService,
            chatService: widget.chatService,
            storyService: widget.storyService,
            dropService: widget.dropService,
            contentCategoryService: widget.contentCategoryService,
            userTagService: widget.userTagService,
            artistTagService: widget.artistTagService,
            safetyService: widget.safetyService,
            storeProfileService: widget.storeProfileService,
            initialFancamId: _fancamKey(fancam),
            showBackButton: true,
          ),
        ),
      );
      return;
    }
    if (_isPublishedPostActivity(activity)) {
      _openPublishedPostFeed(activity);
      return;
    }
    _openActivityOptions(activity);
  }

  void _openPublishedPostFeed(_ProfileActivity selectedActivity) {
    final postActivities = _activitiesFor(
      _ProfileTab.posts,
    ).where(_isPublishedPostActivity).toList(growable: false);
    final selectedIndex = postActivities.indexWhere(
      (activity) => activity.id == selectedActivity.id,
    );
    if (selectedIndex < 0) return;

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _ProfilePostsFeedScreen(
          username: user.username,
          activities: postActivities.sublist(selectedIndex),
          itemBuilder: (context, activity, refresh, remove) {
            final post = _publishedPostsByActivityId[activity.id];
            if (post == null) return const SizedBox.shrink();
            return HallyuPostCard(
              post: post,
              liked: _starredItems.contains(activity.id),
              saved: _savedItems.contains(activity.id),
              shared: false,
              likesLabel: _countWithDelta(
                activity.stars,
                (_starredItems.contains(activity.id) ? 1 : 0) -
                    (activity.starredByCurrentUser ? 1 : 0),
              ),
              commentsLabel: _countWithDelta(
                activity.comments,
                _commentAdditions[activity.id] ?? 0,
              ),
              sharesLabel: post.shares,
              savesLabel: post.saves,
              onLike: () {
                _toggleStar(activity).whenComplete(refresh);
              },
              onComment: () {
                _openComments(activity).whenComplete(refresh);
              },
              onShare: () => _openShareSheet(
                title: 'Compartir publicación',
                subtitle: activity.title,
                shareText:
                    '${activity.title}\n${ShareLinks.publication(activity.id)}',
              ),
              onSave: () {
                _toggleSaved(activity).whenComplete(refresh);
              },
              onOpenTaggedEntity: _openKpopEntity,
              onMore: () => _openActivityOptions(
                activity,
                onChanged: refresh,
                onDeleted: remove,
              ),
              secondaryLabel: activity.title,
              bottomPadding: 18,
            );
          },
        ),
      ),
    );
  }

  void _openActivityOptions(
    _ProfileActivity activity, {
    VoidCallback? onChanged,
    VoidCallback? onDeleted,
  }) {
    final profile = activity.sharedByCommunity
        ? _profileById(activity.profileId)
        : null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileActionSheet(
        title: activity.title,
        subtitle: activity.subtitle,
        actions: [
          if (profile != null)
            _SheetAction(
              icon: Icons.person_outline,
              title: 'Ver perfil de ${profile.name}',
              detail: _communityProfileSubtitle(profile),
              onTap: () {
                Navigator.of(context).pop();
                _openPersonProfile(profile);
              },
            )
          else
            _SheetAction(
              icon: Icons.person_outline,
              title: 'Publicado por vos',
              detail: '${user.name} · ${user.username}',
              onTap: () =>
                  _completeSheetAction(context, 'Esta publicación es tuya.'),
            ),
          _SheetAction(
            icon: Icons.mode_comment_outlined,
            title: 'Ver detalle y comentarios',
            detail: activity.detail.trim().isEmpty
                ? 'Abrir conversación de la publicación.'
                : activity.detail,
            onTap: () {
              Navigator.of(context).pop();
              _openComments(activity).whenComplete(() => onChanged?.call());
            },
          ),
          _SheetAction(
            icon: Icons.share_outlined,
            title: 'Compartir',
            detail: 'Enviar esta actividad.',
            onTap: () {
              Navigator.of(context).pop();
              _openShareSheet(
                title: 'Compartir publicación',
                subtitle: activity.title,
                shareText:
                    '${activity.title}\n'
                    '${ShareLinks.publication(activity.id)}',
              );
            },
          ),
          _SheetAction(
            icon: Icons.bookmark_border,
            title: _savedItems.contains(activity.id)
                ? 'Quitar guardado'
                : 'Guardar',
            detail: 'Organizar en tu colección.',
            onTap: () async {
              Navigator.of(context).pop();
              await _toggleSaved(activity);
              onChanged?.call();
            },
          ),
          if (_isPublishedPostActivity(activity))
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              title: 'Eliminar publicación',
              detail: 'Quitarla de tu perfil y del feed.',
              onTap: () async {
                Navigator.of(context).pop();
                final deleted = await _deletePublishedPost(activity);
                if (deleted) onDeleted?.call();
              },
            ),
        ],
      ),
    );
  }

  Future<bool> _deletePublishedPost(_ProfileActivity activity) async {
    if (!_isPublishedPostActivity(activity)) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          '¿Eliminar esta publicación?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await widget.postService.deletePost(activity.id);
      if (!mounted) return false;
      setState(() {
        _publishedPostsByActivityId.remove(activity.id);
        _publishedPostActivities.removeWhere((item) => item.id == activity.id);
        _contentCategoryAssignments = _contentCategoryAssignments
            .where(
              (item) =>
                  item.contentType != ProfileContentType.post ||
                  item.contentId != activity.id,
            )
            .toList(growable: false);
        _savedItems.remove(activity.id);
        _starredItems.remove(activity.id);
        _commentsByActivity.remove(activity.id);
      });
      _showSnack('Publicación eliminada');
      return true;
    } on PostServiceException catch (error) {
      if (!mounted) return false;
      _showSnack(error.message);
    } catch (error) {
      debugPrint('PROFILE_DELETE_POST_ERROR id=${activity.id} error=$error');
      if (!mounted) return false;
      _showSnack('No pudimos eliminar la publicación. Probá de nuevo.');
    }
    return false;
  }

  void _openCollectionItem(CollectionItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _CollectionItemDetailSheet(
        item: item,
        saved: _savedCollectionItems.contains(item.id),
        isOwnItem: item.ownerId == 'local-user',
        onToggleSaved: () {
          Navigator.of(sheetContext).pop();
          _toggleSavedCollection(item);
        },
        onInterest: (action) {
          Navigator.of(sheetContext).pop();
          _sendCollectionInterest(item, action);
        },
        onMessage: () {
          Navigator.of(sheetContext).pop();
          _sendCollectionInterest(item, 'Mensaje sobre');
        },
      ),
    );
  }

  void _toggleSavedCollection(CollectionItem item) {
    setState(() {
      if (!_savedCollectionItems.add(item.id)) {
        _savedCollectionItems.remove(item.id);
      }
    });
    _showSnack(
      _savedCollectionItems.contains(item.id)
          ? 'Item guardado'
          : 'Item quitado de guardados',
    );
  }

  Future<void> _sendCollectionInterest(
    CollectionItem item,
    String action,
  ) async {
    if (item.ownerId == 'local-user') {
      _showSnack('Este item ya es parte de tu perfil');
      return;
    }
    final status = item.isWishlist
        ? 'wishlist'
        : item.isSale
        ? 'venta'
        : item.isTrade
        ? 'trade'
        : 'colección';
    await widget.chatService.sendCollectionInterest(
      item: item,
      body:
          '$action "${item.title}" ($status). '
          '${item.groupArtist}${item.city.isEmpty ? '' : ' · ${item.city}, ${item.country}'}',
    );
    if (!mounted) return;
    _showSnack('Chat creado con ${item.ownerName}');
  }

  bool _isPublishedPostActivity(_ProfileActivity activity) =>
      _publishedPostActivities.any((item) => item.id == activity.id);

  Future<void> _toggleSaved(_ProfileActivity activity) async {
    if (_updatingPublishedSaves.contains(activity.id)) return;
    final isPublishedPost = _isPublishedPostActivity(activity);
    final wasSaved = _savedItems.contains(activity.id);
    final nextSaved = !wasSaved;
    setState(() {
      if (isPublishedPost) _updatingPublishedSaves.add(activity.id);
      if (nextSaved) {
        _savedItems.remove(activity.id);
        _savedItems.add(activity.id);
      } else {
        _savedItems.remove(activity.id);
      }
    });
    try {
      if (isPublishedPost) {
        await widget.postService.setPostSaved(activity.id, nextSaved);
      }
      if (!mounted) return;
      _showSnack(nextSaved ? 'Guardado en perfil' : 'Guardado quitado');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedItems.add(activity.id);
        } else {
          _savedItems.remove(activity.id);
        }
      });
      _showSnack('No pudimos actualizar el guardado. Probá otra vez.');
    } finally {
      if (mounted && isPublishedPost) {
        setState(() => _updatingPublishedSaves.remove(activity.id));
      }
    }
  }

  Future<void> _toggleStar(_ProfileActivity activity) async {
    if (_updatingPublishedStars.contains(activity.id)) return;
    final isPublishedPost = _isPublishedPostActivity(activity);
    final wasStarred = _starredItems.contains(activity.id);
    final nextStarred = !wasStarred;
    setState(() {
      if (isPublishedPost) _updatingPublishedStars.add(activity.id);
      if (nextStarred) {
        _starredItems.add(activity.id);
      } else {
        _starredItems.remove(activity.id);
      }
    });
    try {
      if (isPublishedPost) {
        await widget.postService.setPostLiked(activity.id, nextStarred);
      }
      if (!mounted) return;
      _showSnack(nextStarred ? 'Estrella agregada' : 'Estrella quitada');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasStarred) {
          _starredItems.add(activity.id);
        } else {
          _starredItems.remove(activity.id);
        }
      });
      _showSnack('No pudimos actualizar la estrella. Probá otra vez.');
    } finally {
      if (mounted && isPublishedPost) {
        setState(() => _updatingPublishedStars.remove(activity.id));
      }
    }
  }

  List<PostComment> _commentsFor(_ProfileActivity activity) {
    if (widget.postService.usesRealPosts ||
        widget.followService.usesRealProfiles) {
      return _commentsByActivity.putIfAbsent(activity.id, () => []);
    }
    return _commentsByActivity.putIfAbsent(
      activity.id,
      () => [
        PostComment(
          author: _profileById(activity.profileId).name,
          username: _profileById(activity.profileId).username,
          avatarAsset: _profileById(activity.profileId).avatarAsset,
          body: activity.sharedByCommunity
              ? 'Lo compartí porque encaja perfecto con este perfil.'
              : 'Qué lindo encontrar esta publicación en tu perfil.',
          time: 'Hace 8 min',
        ),
      ],
    );
  }

  Future<void> _openComments(_ProfileActivity activity) async {
    final isPublishedPost = _isPublishedPostActivity(activity);
    List<PostComment> initialComments;
    try {
      initialComments = isPublishedPost
          ? await widget.postService.restoreComments(activity.id)
          : _commentsFor(activity);
    } on PostServiceException catch (error) {
      if (error.message.contains('no está disponible')) {
        if (mounted) {
          setState(() {
            _publishedPostActivities.removeWhere(
              (item) => item.id == activity.id,
            );
            _publishedPostsByActivityId.remove(activity.id);
            _commentsByActivity.remove(activity.id);
          });
          _showSnack(error.message);
        }
        return;
      }
      initialComments = widget.postService.usesRealPosts
          ? <PostComment>[]
          : _commentsFor(activity);
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      initialComments = widget.postService.usesRealPosts
          ? <PostComment>[]
          : _commentsFor(activity);
      if (mounted) _showSnack('No pudimos cargar comentarios reales.');
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        threadId: activity.id,
        subtitle: activity.title,
        initialComments: initialComments,
        currentUserName: user.name,
        currentUsername: user.username,
        currentUserAvatar: user.avatarAsset,
        safetyService: widget.safetyService,
        reportContentType: 'comment',
        onSubmitComment: isPublishedPost
            ? (body, parentId) => widget.postService.addComment(
                author: user,
                postId: activity.id,
                body: body,
                parentId: parentId,
              )
            : null,
        onDeleteComment: isPublishedPost
            ? (comment) => widget.postService.deleteComment(
                postId: activity.id,
                commentId: comment.id,
              )
            : null,
        onOpenAuthor: _openCommentAuthor,
        onChanged: (comments) {
          setState(() {
            _commentsByActivity[activity.id] = comments;
          });
        },
        onCommentAdded: () {
          if (isPublishedPost) return;
          setState(() {
            _commentAdditions.update(
              activity.id,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          });
        },
        onCommentsRemoved: (count) {
          if (isPublishedPost) return;
          setState(() {
            _commentAdditions.update(
              activity.id,
              (value) => (value - count).clamp(0, 999999),
              ifAbsent: () => 0,
            );
          });
        },
      ),
    );
  }

  Future<void> _toggleFollow(_DemoProfile profile) async {
    final wasFollowing = _followedProfiles.contains(profile.id);
    setState(() {
      if (wasFollowing) {
        _followedProfiles.remove(profile.id);
      } else {
        _followedProfiles.add(profile.id);
      }
    });
    try {
      final nowFollowing = await widget.followService.toggleFollowing(
        profile.id,
      );
      await _restoreFollowing();
      if (!mounted) return;
      _showSnack(
        nowFollowing
            ? 'Siguiendo a ${profile.name}'
            : 'Dejaste de seguir a ${profile.name}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFollowing) {
          _followedProfiles.add(profile.id);
        } else {
          _followedProfiles.remove(profile.id);
        }
      });
      _showSnack('No pudimos actualizar el seguimiento.');
    }
  }

  Future<void> _openCommentAuthor(PostComment comment) async {
    final resolved = await _resolveRealProfile(
      id: comment.authorId,
      username: comment.username,
      name: comment.author,
    );
    if (resolved != null) {
      if (!mounted) return;
      _openPersonProfile(_DemoProfile.fromCommunity(resolved));
      return;
    }
    final profile = _DemoProfile(
      id: comment.authorId.isEmpty ? comment.username : comment.authorId,
      name: comment.author,
      username: comment.username,
      city: '',
      country: '',
      fandom: '',
      favoriteGroup: '',
      bio: '',
      avatarAsset: comment.avatarAsset,
      coverAsset: 'assets/demo-posts/post-01.jpg',
      posts: '',
      followers: '',
      following: '',
      stars: '',
      level: 1,
      colors: const [AppTheme.cyan, AppTheme.rose, AppTheme.night],
    );
    _openPersonProfile(profile);
  }

  Future<CommunityProfile?> _resolveRealProfile({
    required String id,
    required String username,
    required String name,
  }) async {
    if (!widget.followService.usesRealProfiles) return null;
    final query = id.isNotEmpty ? id : username.replaceFirst('@', '');
    if (query.trim().isEmpty) return null;
    try {
      final profiles = await widget.followService.restoreProfiles(
        query: query,
        limit: 24,
      );
      if (profiles.isEmpty) return null;
      final normalizedUsername = username.replaceFirst('@', '').toLowerCase();
      return profiles.firstWhere(
        (profile) =>
            profile.id == id ||
            profile.username.replaceFirst('@', '').toLowerCase() ==
                normalizedUsername,
        orElse: () => profiles.first,
      );
    } catch (error) {
      debugPrint('COMMENT_AUTHOR_PROFILE_RESOLVE_ERROR profile $error');
      return null;
    }
  }

  void _openMessageComposer(_DemoProfile profile) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DirectChatScreen(
          profile: _communityProfileFromDemo(profile),
          chatService: widget.chatService,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          safetyService: widget.safetyService,
        ),
      ),
    );
  }

  CommunityProfile _communityProfileFromDemo(_DemoProfile profile) {
    return CommunityProfile(
      id: profile.id,
      name: profile.name,
      username: profile.username,
      city: profile.city,
      country: profile.country,
      fandom: profile.fandom,
      favoriteGroup: profile.favoriteGroup,
      bio: profile.bio,
      avatarAsset: profile.avatarAsset,
      followers: profile.followers,
      posts: profile.posts,
      colors: profile.colors,
      following: profile.following,
      starsReceived: profile.stars,
      level: profile.level,
      coverAsset: profile.coverAsset,
      online: profile.online,
    );
  }

  void _openPersonProfile(_DemoProfile profile) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          profile: _communityProfileFromDemo(profile),
          currentUser: user,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          chatService: widget.chatService,
          contentCategoryService: widget.contentCategoryService,
          userTagService: widget.userTagService,
          artistTagService: widget.artistTagService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _selectedContentCategory;
    final activities = selectedCategory == null
        ? _activitiesFor(_selectedTab)
        : _activitiesForProfileCategory(selectedCategory);
    final activityTitle =
        selectedCategory?.label ??
        switch (_selectedTab) {
          _ProfileTab.posts => 'Publicaciones',
          _ProfileTab.drops => 'Drops',
          _ProfileTab.fancams => 'Fancams',
          _ProfileTab.outfit => 'Outfits',
          _ProfileTab.photocards => 'Photocards',
          _ProfileTab.collection => 'Colección',
          _ProfileTab.trades => 'Trades y ventas',
          _ProfileTab.wishlist => 'Wishlist',
          _ProfileTab.saved => 'Guardado',
          _ProfileTab.archive => 'Archivo',
        };

    final content = <Widget>[
      const HallyFeatureTip(
        featureId: 'profile_intro',
        title: 'Este es tu espacio ✨',
        message: 'Personalizá tu perfil y elegí qué compartir.',
        mascotAsset: 'assets/brand/hally_mascot_wave_transparent.png',
      ),
      PremiumProfileFeatureDeck(
        items: [
          ProfileFeatureItem(
            id: 'posts',
            title: 'Mis posts',
            value: _activitiesFor(_ProfileTab.posts).length.toString(),
            detail: 'publicaciones',
            icon: Icons.edit_note_rounded,
            colors: const [AppTheme.rose, AppTheme.violet],
            onTap: () => _focusProfileTab(_ProfileTab.posts),
            previews: _profileFeaturePreviews(
              _activitiesFor(_ProfileTab.posts),
            ),
          ),
          ProfileFeatureItem(
            id: 'fancams',
            title: 'Mis fancams',
            value: _activitiesFor(_ProfileTab.fancams).length.toString(),
            detail: 'videos',
            icon: Icons.videocam_rounded,
            colors: const [AppTheme.violet, AppTheme.cyan],
            onTap: () => _focusProfileTab(_ProfileTab.fancams),
            previews: _profileFeaturePreviews(
              _activitiesFor(_ProfileTab.fancams),
            ),
          ),
          ProfileFeatureItem(
            id: 'photocards',
            title: 'Photocards',
            value:
                (_profileCategoryCounts[ProfileContentCategory.photocards] ?? 0)
                    .toString(),
            detail: 'guardadas',
            icon: Icons.style_rounded,
            colors: const [AppTheme.cyan, AppTheme.teal],
            onTap: () =>
                _focusProfileCategory(ProfileContentCategory.photocards),
            previews: _profileFeaturePreviews(
              _activitiesForProfileCategory(ProfileContentCategory.photocards),
            ),
          ),
          ProfileFeatureItem(
            id: 'collection',
            title: 'Mi colección',
            value: _ownCollectionItems.length.toString(),
            detail: 'items',
            icon: Icons.collections_bookmark_rounded,
            colors: const [AppTheme.indigo, AppTheme.rose],
            onTap: () => _focusProfileTab(_ProfileTab.collection),
          ),
        ],
      ),
      if (_storeProfile != null) ...[
        const SizedBox(height: 18),
        StoreProfileCard(
          store: _storeProfile!,
          avatarAsset: user.avatarAsset,
          followersLabel: _formatCompactCount(_currentFollowCounts.followers),
          postsLabel: _activitiesFor(_ProfileTab.posts).length.toString(),
          savesLabel: _savedItems.length.toString(),
          isOwnProfile: true,
          onSettings: () => _openSettings(initialPanel: 'storeProfile'),
        ),
      ],
      const SizedBox(height: 18),
      ProfileCategoryRail(
        counts: _profileCategoryCounts,
        selected: selectedCategory,
        onSelected: (category) {
          setState(() {
            _selectedContentCategory = category;
          });
        },
      ),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: _profileContentKey,
        child: Builder(
          builder: (anchorContext) {
            _rememberProfileContentOffset(anchorContext);
            return ProfileVisualSectionHeader(
              title: activityTitle,
              icon: Icons.grid_view_rounded,
            );
          },
        ),
      ),
      if (selectedCategory == null) const SizedBox(height: 12),
      if (selectedCategory != null)
        _ProfileCategorySection(
          category: selectedCategory,
          activities: activities,
          buildActivity: _buildActivityCard,
        )
      else if (_selectedTab == _ProfileTab.archive)
        _ArchiveCard(
          onCreateStory: _openCreateSheet,
          onOpenArchive: _openStoryArchive,
        )
      else if (_selectedTab == _ProfileTab.collection)
        _CollectionSection(
          title: 'Colección',
          subtitle:
              'Tu binder digital: photocards, álbumes, merch y objetos fandom.',
          emptyTitle: 'Tu colección todavía está vacía',
          emptyDetail: 'Agregá tu primera photocard, álbum o lightstick.',
          items: _ownCollectionItems,
          savedItems: _savedCollectionItems,
          onOpen: _openCollectionItem,
          onCreate: () => _openCollectionEditor(
            context,
            _CollectionCreateMode.collection,
            closeSource: false,
          ),
        )
      else if (_selectedTab == _ProfileTab.trades)
        _CollectionSection(
          title: 'Trades y ventas',
          subtitle:
              'Items disponibles para intercambio o consulta por mensaje.',
          emptyTitle: 'Todavía no hay trades o ventas',
          emptyDetail: 'Publicá un item disponible sin activar pagos reales.',
          items: _tradeSaleItems,
          savedItems: _savedCollectionItems,
          onOpen: _openCollectionItem,
          onCreate: () => _openCollectionEditor(
            context,
            _CollectionCreateMode.tradeSale,
            closeSource: false,
          ),
        )
      else if (_selectedTab == _ProfileTab.wishlist)
        _CollectionSection(
          title: 'Wishlist',
          subtitle: 'Lo que estás buscando y lo que otros fans pueden tener.',
          emptyTitle: 'Tu wishlist está vacía',
          emptyDetail: 'Agregá una photocard, álbum o merch que querés buscar.',
          items: _wishlistItems,
          savedItems: _savedCollectionItems,
          onOpen: _openCollectionItem,
          onCreate: () => _openCollectionEditor(
            context,
            _CollectionCreateMode.wishlist,
            closeSource: false,
          ),
        )
      else if (activities.isEmpty)
        _EmptyProfileState(tab: _selectedTab)
      else
        _ProfileActivityGrid(
          activities: activities,
          itemBuilder: _buildActivityGridTile,
        ),
    ];

    return CustomScrollView(
      key: const ValueKey('profile-scroll'),
      controller: _scrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(900),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _ProfileHero(
              user: user,
              stats: _currentProfileStats,
              progress: _fanProgress(_receivedStars),
              onOpenSettings: () => _openSettings(),
              onEditProfile: () => _openSettings(initialPanel: 'editProfile'),
              onChangePhoto: _changeProfilePhoto,
              onCreate: _openCreateSheet,
              onShare: _openShareSheet,
              onOpenStat: _openOwnStat,
              onOpenInterest: _openProfileInterest,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileTabsHeaderDelegate(
            child: _ProfileTabs(
              selected: _selectedTab,
              onChanged: _focusProfileTab,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          sliver: SliverList(delegate: SliverChildListDelegate(content)),
        ),
      ],
    );
  }

  List<Widget> _profileFeaturePreviews(List<_ProfileActivity> activities) {
    return activities
        .take(3)
        .map<Widget>(
          (activity) => _ProfileActivityThumbnail(activity: activity),
        )
        .toList(growable: false);
  }

  Widget _buildActivityCard(_ProfileActivity activity) {
    final publishedPost = _publishedPostsByActivityId[activity.id];
    if (publishedPost != null) {
      return HallyuPostCard(
        post: publishedPost,
        liked: _starredItems.contains(activity.id),
        saved: _savedItems.contains(activity.id),
        shared: false,
        likesLabel: _countWithDelta(
          activity.stars,
          (_starredItems.contains(activity.id) ? 1 : 0) -
              (activity.starredByCurrentUser ? 1 : 0),
        ),
        commentsLabel: _countWithDelta(
          activity.comments,
          _commentAdditions[activity.id] ?? 0,
        ),
        sharesLabel: publishedPost.shares,
        savesLabel: publishedPost.saves,
        onLike: () => _toggleStar(activity),
        onComment: () => _openComments(activity),
        onShare: () => _openShareSheet(
          title: 'Compartir publicación',
          subtitle: activity.title,
          shareText:
              '${activity.title}\n${ShareLinks.publication(activity.id)}',
        ),
        onSave: () => _toggleSaved(activity),
        onOpenProfile: null,
        onOpenTaggedEntity: _openKpopEntity,
        onMore: () => _openActivityOptions(activity),
        secondaryLabel: activity.title,
        bottomPadding: 18,
      );
    }
    final profile = _profileById(activity.profileId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ProfileActivityCard(
        activity: activity,
        profile: profile,
        owner: user,
        saved: _savedItems.contains(activity.id),
        starred: _starredItems.contains(activity.id),
        starsLabel: _countWithDelta(
          activity.stars,
          (_starredItems.contains(activity.id) ? 1 : 0) -
              (activity.starredByCurrentUser ? 1 : 0),
        ),
        commentsLabel: _countWithDelta(
          activity.comments,
          _commentAdditions[activity.id] ?? 0,
        ),
        following: _followedProfiles.contains(profile.id),
        onOpen: () => _openActivityDetail(activity),
        onProfile: () => _openPersonProfile(profile),
        onFollow: () => _toggleFollow(profile),
        onMessage: () => _openMessageComposer(profile),
        onSave: () => _toggleSaved(activity),
        onStar: () => _toggleStar(activity),
        onComment: () => _openComments(activity),
        onShare: () => _openShareSheet(
          title: 'Compartir publicación',
          subtitle: activity.title,
          shareText:
              '${activity.title}\n${ShareLinks.publication(activity.id)}',
        ),
        onMore: () => _openActivityOptions(activity),
      ),
    );
  }

  Widget _buildActivityGridTile(_ProfileActivity activity) {
    final profile = _profileById(activity.profileId);
    return _ProfileActivityGridTile(
      activity: activity,
      profile: profile,
      owner: user,
      saved: _savedItems.contains(activity.id),
      starred: _starredItems.contains(activity.id),
      starsLabel: _countWithDelta(
        activity.stars,
        (_starredItems.contains(activity.id) ? 1 : 0) -
            (activity.starredByCurrentUser ? 1 : 0),
      ),
      commentsLabel: _countWithDelta(
        activity.comments,
        _commentAdditions[activity.id] ?? 0,
      ),
      onOpen: () => _openActivityDetail(activity),
      onAuthor: () => activity.sharedByCommunity
          ? _openPersonProfile(profile)
          : _openActivityDetail(activity),
      onStar: () => _toggleStar(activity),
      onComment: () => _openComments(activity),
      onSave: () => _toggleSaved(activity),
      onMore: () => _openActivityOptions(activity),
    );
  }

  List<_ProfileActivity> _activitiesFor(_ProfileTab tab) {
    final base = _allActivities;
    switch (tab) {
      case _ProfileTab.posts:
        return base.where((item) => item.tab == _ProfileTab.posts).toList();
      case _ProfileTab.drops:
        return base.where((item) => item.tab == _ProfileTab.drops).toList();
      case _ProfileTab.fancams:
        return base.where((item) => item.tab == _ProfileTab.fancams).toList();
      case _ProfileTab.outfit:
        return base.where((item) => item.tab == _ProfileTab.outfit).toList();
      case _ProfileTab.photocards:
        return base
            .where((item) => item.tab == _ProfileTab.photocards)
            .toList();
      case _ProfileTab.collection:
      case _ProfileTab.trades:
      case _ProfileTab.wishlist:
        return const [];
      case _ProfileTab.saved:
        final savedOrder = _savedItems.toList(growable: false);
        final savedActivities = base
            .where((item) => _savedItems.contains(item.id))
            .toList();
        savedActivities.sort((a, b) {
          return savedOrder.indexOf(b.id).compareTo(savedOrder.indexOf(a.id));
        });
        return savedActivities;
      case _ProfileTab.archive:
        return const [];
    }
  }
}

class _ProfileCategorySection extends StatelessWidget {
  const _ProfileCategorySection({
    required this.category,
    required this.activities,
    required this.buildActivity,
  });

  final ProfileContentCategory category;
  final List<_ProfileActivity> activities;
  final Widget Function(_ProfileActivity activity) buildActivity;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppTheme.cyan),
            const SizedBox(height: 10),
            Text(
              'Todavía no hay contenido en ${category.label}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando publiques algo, elegí esta categoría para organizarlo en tu perfil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
            ),
          ],
        ),
      );
    }
    return Column(children: activities.map(buildActivity).toList());
  }
}

class _ProfilePostsFeedScreen extends StatefulWidget {
  const _ProfilePostsFeedScreen({
    required this.username,
    required this.activities,
    required this.itemBuilder,
  });

  final String username;
  final List<_ProfileActivity> activities;
  final Widget Function(
    BuildContext context,
    _ProfileActivity activity,
    VoidCallback refresh,
    VoidCallback remove,
  )
  itemBuilder;

  @override
  State<_ProfilePostsFeedScreen> createState() =>
      _ProfilePostsFeedScreenState();
}

class _ProfilePostsFeedScreenState extends State<_ProfilePostsFeedScreen> {
  late final List<_ProfileActivity> _activities = List.of(widget.activities);

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _remove(_ProfileActivity activity) {
    if (!mounted) return;
    setState(() => _activities.removeWhere((item) => item.id == activity.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('profile-posts-feed'),
      backgroundColor: const Color(0xFF05070D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publicaciones',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              widget.username,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _activities.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Esta publicación ya no está disponible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                key: const ValueKey('profile-posts-feed-scroll'),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                physics: const BouncingScrollPhysics(),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final activity = _activities[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: widget.itemBuilder(
                        context,
                        activity,
                        _refresh,
                        () => _remove(activity),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.stats,
    required this.progress,
    required this.onOpenSettings,
    required this.onEditProfile,
    required this.onChangePhoto,
    required this.onCreate,
    required this.onShare,
    required this.onOpenStat,
    required this.onOpenInterest,
  });

  final AuthUser user;
  final List<ProfileStat> stats;
  final _FanProgress progress;
  final VoidCallback onOpenSettings;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePhoto;
  final VoidCallback onCreate;
  final VoidCallback onShare;
  final ValueChanged<String> onOpenStat;
  final ValueChanged<String> onOpenInterest;

  @override
  Widget build(BuildContext context) {
    final colors = _profileBackgroundColors(user.profileBackground);
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0D17),
            colors.first.withValues(alpha: 0.075),
            const Color(0xFF05070D),
            colors.last.withValues(alpha: 0.045),
          ],
          stops: const [0, 0.34, 0.74, 1],
        ),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.025),
                    Colors.transparent,
                    AppTheme.night.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.rose,
                              AppTheme.violet,
                              AppTheme.cyan,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.violet.withValues(alpha: 0.24),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: HubAvatar(
                          asset: user.avatarAsset,
                          size: 116,
                          isLive: true,
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: IconButton.filled(
                          key: const ValueKey('profile-change-avatar'),
                          onPressed: onChangePhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 17,
                          ),
                          tooltip: 'Cambiar foto de perfil',
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.rose,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('profile-settings-open'),
                              onPressed: onOpenSettings,
                              icon: const Icon(Icons.tune_rounded, size: 19),
                              tooltip: 'Ajustes',
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(
                                  0xFF111522,
                                ).withValues(alpha: 0.88),
                                minimumSize: const Size(40, 40),
                                padding: EdgeInsets.zero,
                                side: BorderSide(
                                  color: AppTheme.violet.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (user.accountVerified) ...[
                          const SizedBox(height: 6),
                          const _VerifiedBadge(label: 'Verificado'),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '${user.username} · ${user.publicLocationLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.cyan.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          user.bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 13,
                            height: 1.24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InlineProfileStats(stats: stats, onTap: onOpenStat),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: FilledButton.icon(
                                key: const ValueKey('profile-create'),
                                onPressed: onCreate,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Crear', maxLines: 1),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.rose,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              fit: FlexFit.tight,
                              child: OutlinedButton.icon(
                                key: const ValueKey('profile-edit'),
                                onPressed: onEditProfile,
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text('Editar', maxLines: 1),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: AppTheme.rose.withValues(alpha: 0.5),
                                  ),
                                  minimumSize: const Size.fromHeight(38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              key: const ValueKey('profile-share'),
                              onPressed: onShare,
                              icon: const Icon(Icons.share_outlined, size: 18),
                              tooltip: 'Compartir perfil',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                foregroundColor: Colors.white,
                                fixedSize: const Size(38, 38),
                                padding: EdgeInsets.zero,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Mis fandoms',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Nivel ${progress.level}',
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FandomStrip(
                keyPrefix: 'profile',
                onTap: onOpenInterest,
                labels: [
                  user.fandom.trim().isEmpty ? 'Agregar fandom' : user.fandom,
                  user.bias.trim().isEmpty
                      ? 'Agregar bias'
                      : 'Bias: ${user.bias}',
                  user.favoriteGroup.trim().isEmpty
                      ? 'Agregar grupo favorito'
                      : user.favoriteGroup,
                ],
              ),
              const SizedBox(height: 10),
              _ProgressCard(progress: progress),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.rose]),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.night,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AvatarPreviewSheet extends StatelessWidget {
  const _AvatarPreviewSheet({
    required this.bytes,
    required this.onCancel,
    required this.onSave,
  });

  final Uint8List bytes;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nueva foto de perfil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Así se va a ver tu avatar en perfil, historias y publicaciones.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
                  ),
                ),
                child: ClipOval(
                  child: Image.memory(
                    bytes,
                    width: 118,
                    height: 118,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('profile-save-avatar'),
                    onPressed: onSave,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineProfileStats extends StatelessWidget {
  const _InlineProfileStats({required this.stats, required this.onTap});

  final List<ProfileStat> stats;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(
            child: InkWell(
              key: ValueKey('profile-stat-${stats[index].label}'),
              onTap: () => onTap(stats[index].label),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats[index].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      stats[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (index != stats.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.stats,
    required this.keyPrefix,
    required this.onTap,
  });

  final List<ProfileStat> stats;
  final String keyPrefix;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < stats.length; index++) ...[
            Expanded(
              child: InkWell(
                key: ValueKey('$keyPrefix-stat-${stats[index].label}'),
                onTap: () => onTap(stats[index].label),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 3,
                  ),
                  child: Column(
                    children: [
                      Text(
                        stats[index].value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index != stats.length - 1)
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.09),
              ),
          ],
        ],
      ),
    );
  }
}

class _FandomStrip extends StatelessWidget {
  const _FandomStrip({
    required this.labels,
    required this.keyPrefix,
    required this.onTap,
  });

  final List<String> labels;
  final String keyPrefix;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final visibleLabels = labels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: visibleLabels.map((label) {
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: InkWell(
              key: ValueKey('$keyPrefix-interest-$label'),
              onTap: () => onTap(label),
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppTheme.violet.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final _FanProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111522).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 27,
            height: 27,
            child: CircularProgressIndicator(
              value: progress.percent,
              strokeWidth: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppTheme.cyan),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nivel fandom ${progress.level}',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  '${progress.stars} estrellas para el próximo nivel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selected, required this.onChanged});

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = {
      _ProfileTab.posts: 'Publicaciones',
      _ProfileTab.collection: 'Colección',
      _ProfileTab.trades: 'Trades/Ventas',
      _ProfileTab.wishlist: 'Wishlist',
      _ProfileTab.drops: 'Drops',
      _ProfileTab.fancams: 'Fancams',
      _ProfileTab.saved: 'Guardado',
      _ProfileTab.archive: 'Archivo',
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.entries.map((entry) {
            final isSelected = selected == entry.key;
            return InkWell(
              key: ValueKey('profile-tab-${entry.key.name}'),
              onTap: () => onChanged(entry.key),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? AppTheme.violet.withValues(alpha: 0.2)
                      : Colors.transparent,
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.violet.withValues(alpha: 0.48),
                        )
                      : null,
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.68),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabsHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF05070D).withValues(alpha: 0.97),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 7),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _ProfileActivityGrid extends StatelessWidget {
  const _ProfileActivityGrid({
    required this.activities,
    required this.itemBuilder,
  });

  final List<_ProfileActivity> activities;
  final Widget Function(_ProfileActivity activity) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 680 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) => itemBuilder(activities[index]),
        );
      },
    );
  }
}

class _ProfileActivityGridTile extends StatelessWidget {
  const _ProfileActivityGridTile({
    required this.activity,
    required this.profile,
    required this.owner,
    required this.saved,
    required this.starred,
    required this.starsLabel,
    required this.commentsLabel,
    required this.onOpen,
    required this.onAuthor,
    required this.onStar,
    required this.onComment,
    required this.onSave,
    required this.onMore,
  });

  final _ProfileActivity activity;
  final _DemoProfile profile;
  final AuthUser owner;
  final bool saved;
  final bool starred;
  final String starsLabel;
  final String commentsLabel;
  final VoidCallback onOpen;
  final VoidCallback onAuthor;
  final VoidCallback onStar;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final displayName = activity.sharedByCommunity ? profile.name : owner.name;
    final displayAvatar = activity.sharedByCommunity
        ? profile.avatarAsset
        : owner.avatarAsset;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('profile-activity-open-${activity.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF090C15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProfileActivityThumbnail(activity: activity),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                      stops: const [0, 0.28, 0.55, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  right: 34,
                  child: InkWell(
                    key: ValueKey('profile-activity-author-${activity.id}'),
                    onTap: onAuthor,
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      children: [
                        HubAvatar(
                          asset: displayAvatar,
                          size: 25,
                          isLive: activity.sharedByCommunity
                              ? profile.online
                              : true,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(blurRadius: 7, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 1,
                  child: IconButton(
                    key: ValueKey('profile-activity-more-${activity.id}'),
                    onPressed: onMore,
                    icon: const Icon(Icons.more_horiz_rounded, size: 17),
                    color: Colors.white,
                    tooltip: 'Más opciones',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.28),
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 37,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activity.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 2,
                  right: 2,
                  bottom: 2,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF080A12).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileGridAction(
                            key: ValueKey(
                              'profile-activity-star-${activity.id}',
                            ),
                            icon: starred ? Icons.star : Icons.star_border,
                            label: starsLabel,
                            active: starred,
                            tooltip: starred
                                ? 'Quitar estrella'
                                : 'Dar estrella',
                            onPressed: onStar,
                          ),
                        ),
                        Expanded(
                          child: _ProfileGridAction(
                            key: ValueKey(
                              'profile-activity-comment-${activity.id}',
                            ),
                            icon: Icons.mode_comment_outlined,
                            label: commentsLabel,
                            tooltip: 'Comentar',
                            onPressed: onComment,
                          ),
                        ),
                        Expanded(
                          child: _ProfileGridAction(
                            key: ValueKey(
                              'profile-activity-save-${activity.id}',
                            ),
                            icon: saved
                                ? Icons.bookmark
                                : Icons.bookmark_border_rounded,
                            active: saved,
                            tooltip: saved ? 'Quitar guardado' : 'Guardar',
                            onPressed: onSave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (activity.containsVideo)
                  const Positioned(
                    right: 8,
                    top: 40,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 22,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileGridAction extends StatelessWidget {
  const _ProfileGridAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label = '',
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? AppTheme.rose
        : Colors.white.withValues(alpha: 0.82);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: foreground),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileActivityThumbnail extends StatelessWidget {
  const _ProfileActivityThumbnail({required this.activity});

  final _ProfileActivity activity;

  @override
  Widget build(BuildContext context) {
    final item = activity.mediaItems.isEmpty ? null : activity.mediaItems.first;
    final bytes = item?.imageBytes ?? activity.imageBytes;
    final imageAsset = (item?.imageAsset ?? '').trim().isNotEmpty
        ? item!.imageAsset
        : activity.imageAsset;
    final mediaPath = (item?.mediaPath ?? '').trim().isNotEmpty
        ? item!.mediaPath
        : activity.mediaPath;
    final isVideo = item?.isVideo ?? activity.containsVideo;
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ProfileThumbnailFallback(isVideo: isVideo),
      );
    } else if (imageAsset.startsWith('http://') ||
        imageAsset.startsWith('https://')) {
      image = Image.network(
        imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ProfileThumbnailFallback(isVideo: isVideo),
      );
    } else if (imageAsset.trim().isNotEmpty) {
      image = Image.asset(
        imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ProfileThumbnailFallback(isVideo: isVideo),
      );
    } else if (!isVideo &&
        (mediaPath.startsWith('http://') || mediaPath.startsWith('https://'))) {
      image = Image.network(
        mediaPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _ProfileThumbnailFallback(),
      );
    } else {
      image = _ProfileThumbnailFallback(isVideo: isVideo);
    }
    return ColoredBox(
      color: AppTheme.nightSoft,
      child: SizedBox.expand(child: image),
    );
  }
}

class _ProfileThumbnailFallback extends StatelessWidget {
  const _ProfileThumbnailFallback({this.isVideo = false});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.violet.withValues(alpha: 0.48),
            AppTheme.night,
            AppTheme.cyan.withValues(alpha: 0.24),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined,
          color: Colors.white.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _ProfileActivityCard extends StatelessWidget {
  const _ProfileActivityCard({
    required this.activity,
    required this.profile,
    required this.owner,
    required this.saved,
    required this.starred,
    required this.starsLabel,
    required this.commentsLabel,
    required this.following,
    required this.onOpen,
    required this.onProfile,
    required this.onFollow,
    required this.onMessage,
    required this.onSave,
    required this.onStar,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  final _ProfileActivity activity;
  final _DemoProfile profile;
  final AuthUser owner;
  final bool saved;
  final bool starred;
  final String starsLabel;
  final String commentsLabel;
  final bool following;
  final VoidCallback onOpen;
  final VoidCallback onProfile;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onSave;
  final VoidCallback onStar;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final displayName = activity.sharedByCommunity ? profile.name : owner.name;
    final displayAvatar = activity.sharedByCommunity
        ? profile.avatarAsset
        : owner.avatarAsset;
    final mediaHeight = (MediaQuery.sizeOf(context).width * 1.12).clamp(
      390.0,
      560.0,
    );
    final caption = activity.detail.trim().isEmpty
        ? activity.title
        : activity.detail.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF090511).withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.violet.withValues(alpha: 0.24),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: mediaHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ActivityMedia(
                    activity: activity,
                    height: mediaHeight,
                    width: double.infinity,
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      key: ValueKey('profile-activity-open-${activity.id}'),
                      onTap: onOpen,
                      behavior: HitTestBehavior.opaque,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.58),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.76),
                            ],
                            stops: const [0, 0.28, 0.66, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 15,
                    right: 60,
                    child: InkWell(
                      key: ValueKey('profile-activity-author-${activity.id}'),
                      onTap: activity.sharedByCommunity ? onProfile : onOpen,
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        children: [
                          HubAvatar(
                            asset: displayAvatar,
                            size: 48,
                            isLive: activity.sharedByCommunity
                                ? profile.online
                                : true,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  activity.time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 10,
                    child: IconButton(
                      key: ValueKey('profile-activity-more-${activity.id}'),
                      onPressed: onMore,
                      icon: const Icon(Icons.more_vert_rounded),
                      color: Colors.white,
                      tooltip: 'Más opciones',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.26),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 78,
                    child: _ActivityBadge(label: activity.badge),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: _ProfileActivityGlassActions(
                      children: [
                        _MetricIcon(
                          key: ValueKey('profile-activity-star-${activity.id}'),
                          icon: starred ? Icons.star : Icons.star_border,
                          label: starsLabel,
                          active: starred,
                          tooltip: starred ? 'Quitar estrella' : 'Dar estrella',
                          onPressed: onStar,
                        ),
                        const SizedBox(width: 8),
                        _MetricIcon(
                          key: ValueKey(
                            'profile-activity-comment-${activity.id}',
                          ),
                          icon: Icons.mode_comment_outlined,
                          label: commentsLabel,
                          tooltip: 'Comentar',
                          onPressed: onComment,
                        ),
                        const Spacer(),
                        IconButton(
                          key: ValueKey(
                            'profile-activity-share-${activity.id}',
                          ),
                          onPressed: onShare,
                          icon: const Icon(Icons.share_outlined),
                          color: Colors.white.withValues(alpha: 0.82),
                          tooltip: 'Compartir',
                        ),
                        IconButton(
                          key: ValueKey('profile-activity-save-${activity.id}'),
                          onPressed: onSave,
                          icon: Icon(
                            saved ? Icons.bookmark : Icons.bookmark_border,
                          ),
                          tooltip: saved ? 'Quitar guardado' : 'Guardar',
                          color: saved
                              ? AppTheme.rose
                              : Colors.white.withValues(alpha: 0.82),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$displayName ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: caption,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, height: 1.34),
                  ),
                  if (activity.detail.trim().isNotEmpty &&
                      activity.title.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    activity.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (activity.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activity.tags
                          .map((tag) => _LightTag(label: tag))
                          .toList(growable: false),
                    ),
                  ],
                  if (activity.sharedByCommunity) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            key: ValueKey(
                              'profile-activity-follow-${activity.id}',
                            ),
                            onPressed: onFollow,
                            child: Text(following ? 'Siguiendo' : 'Seguir'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: ValueKey(
                            'profile-activity-message-${activity.id}',
                          ),
                          onPressed: onMessage,
                          icon: const Icon(Icons.chat_bubble_outline),
                          tooltip: 'Mensaje',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActivityGlassActions extends StatelessWidget {
  const _ProfileActivityGlassActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compactChildren = children
        .map((child) => child is Spacer ? const SizedBox(width: 12) : child)
        .toList(growable: false);
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12091C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: compactChildren),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LightTag extends StatelessWidget {
  const _LightTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  const _MetricIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? AppTheme.rose : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTheme.rose : Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.onCreateStory,
    required this.onOpenArchive,
  });

  final VoidCallback onCreateStory;
  final VoidCallback onOpenArchive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock, color: AppTheme.cyan),
          const SizedBox(height: 10),
          const Text(
            'Archivo privado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando subas historias, se guardarán acá para que puedas destacarlas o volver a publicarlas.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('profile-open-story-archive'),
              onPressed: onOpenArchive,
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Abrir archivo'),
            ),
          ),
          const SizedBox(height: 7),
          FilledButton.icon(
            onPressed: onCreateStory,
            icon: const Icon(Icons.add),
            label: const Text('Crear historia'),
          ),
        ],
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState({required this.tab});

  final _ProfileTab tab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        'Todavía no hay contenido en ${tab.name}. Cuando compartas algo, va a aparecer en tu perfil.',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CollectionSection extends StatelessWidget {
  const _CollectionSection({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyDetail,
    required this.items,
    required this.savedItems,
    required this.onOpen,
    required this.onCreate,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyDetail;
  final List<CollectionItem> items;
  final Set<String> savedItems;
  final ValueChanged<CollectionItem> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tradeCount = items.where((item) => item.isTrade).length;
    final saleCount = items.where((item) => item.isSale).length;
    final wishlistCount = items.where((item) => item.isWishlist).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.rose.withValues(alpha: 0.26),
                AppTheme.cyan.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.collections_bookmark_outlined,
                      color: AppTheme.cyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CollectionStatPill(label: '${items.length} items'),
                  if (tradeCount > 0)
                    _CollectionStatPill(label: '$tradeCount trades'),
                  if (saleCount > 0)
                    _CollectionStatPill(label: '$saleCount ventas'),
                  if (wishlistCount > 0)
                    _CollectionStatPill(label: '$wishlistCount wishlist'),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar item'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _CollectionEmptyCard(title: emptyTitle, detail: emptyDetail)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 560;
              if (!twoColumns) {
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CollectionItemCard(
                            item: item,
                            saved: savedItems.contains(item.id),
                            onTap: () => onOpen(item),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _CollectionItemCard(
                    item: item,
                    saved: savedItems.contains(item.id),
                    onTap: () => onOpen(item),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _CollectionStatPill extends StatelessWidget {
  const _CollectionStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CollectionEmptyCard extends StatelessWidget {
  const _CollectionEmptyCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppTheme.cyan),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionItemCard extends StatelessWidget {
  const _CollectionItemCard({
    required this.item,
    required this.saved,
    required this.onTap,
  });

  final CollectionItem item;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _collectionStatusColor(item.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('collection-item-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: statusColor.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: Stack(
                  children: [
                    _CollectionItemImage(
                      item: item,
                      height: 178,
                      width: double.infinity,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _CollectionBadge(
                        label: item.status.label,
                        color: statusColor,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.night.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          saved
                              ? Icons.bookmark
                              : _collectionCategoryIcon(item.category),
                          color: saved ? AppTheme.rose : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        item.groupArtist,
                        if (item.eraAlbum.isNotEmpty) item.eraAlbum,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.ownerId == 'local-user'
                                ? 'Tu perfil'
                                : '${item.ownerName} · ${item.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.isSale && item.price.isNotEmpty)
                          Text(
                            '${item.currency} ${item.price}',
                            style: const TextStyle(
                              color: AppTheme.amber,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionItemImage extends StatelessWidget {
  const _CollectionItemImage({
    required this.item,
    required this.height,
    required this.width,
  });

  final CollectionItem item;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (item.imageBytes != null) {
      return Image.memory(
        item.imageBytes!,
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    }
    return Image.asset(
      item.imageAsset,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _CollectionPlaceholder(
        height: height,
        width: width,
        category: item.category,
      ),
    );
  }
}

class _PublicCollectionPreview extends StatelessWidget {
  const _PublicCollectionPreview({
    required this.ownerName,
    required this.items,
    required this.onOpen,
  });

  final String ownerName;
  final List<CollectionItem> items;
  final ValueChanged<CollectionItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.collections_bookmark_outlined,
                color: AppTheme.cyan,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Colección pública de $ownerName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 142,
                  child: InkWell(
                    key: ValueKey('person-collection-${item.id}'),
                    onTap: () => onOpen(item),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _collectionStatusColor(
                            item.status,
                          ).withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: _CollectionItemImage(
                              item: item,
                              width: double.infinity,
                              height: 95,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.status.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionPlaceholder extends StatelessWidget {
  const _CollectionPlaceholder({
    required this.height,
    required this.width,
    required this.category,
  });

  final double height;
  final double width;
  final CollectionItemCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.rose.withValues(alpha: 0.88),
            AppTheme.cyan.withValues(alpha: 0.72),
            AppTheme.violet.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _collectionCategoryIcon(category),
          color: Colors.white,
          size: 44,
        ),
      ),
    );
  }
}

class _CollectionBadge extends StatelessWidget {
  const _CollectionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CollectionItemDetailSheet extends StatelessWidget {
  const _CollectionItemDetailSheet({
    required this.item,
    required this.saved,
    required this.isOwnItem,
    required this.onToggleSaved,
    required this.onInterest,
    required this.onMessage,
  });

  final CollectionItem item;
  final bool saved;
  final bool isOwnItem;
  final VoidCallback onToggleSaved;
  final ValueChanged<String> onInterest;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final statusColor = _collectionStatusColor(item.status);
    final primaryAction = item.isWishlist
        ? 'Tengo esto'
        : item.isSale
        ? 'Consultar'
        : item.isTrade
        ? 'Me interesa'
        : 'Enviar mensaje';
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.52,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            key: ValueKey('collection-detail-scroll-${item.id}'),
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    _CollectionItemImage(
                      item: item,
                      height: 360,
                      width: double.infinity,
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _CollectionBadge(
                        label: item.status.label,
                        color: statusColor,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  HubAvatar(asset: item.ownerAvatarAsset, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.ownerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${item.ownerUsername} · ${item.city}, ${item.country}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleSaved,
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    color: saved ? AppTheme.rose : Colors.white,
                    tooltip: saved ? 'Quitar guardado' : 'Guardar item',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  item.groupArtist,
                  if (item.eraAlbum.isNotEmpty) item.eraAlbum,
                  item.category.label,
                ].join(' · '),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CollectionStatPill(label: item.rarity),
                  _CollectionStatPill(label: item.condition),
                  _CollectionStatPill(label: item.visibility.label),
                  if (item.isWishlist)
                    _CollectionStatPill(
                      label: 'Prioridad ${item.priority.label}',
                    ),
                  if (item.isSale && item.price.isNotEmpty)
                    _CollectionStatPill(
                      label: '${item.currency} ${item.price}',
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.tradeLookingFor.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CollectionInfoBlock(
                  icon: item.isWishlist
                      ? Icons.favorite_border_rounded
                      : Icons.swap_horiz_rounded,
                  title: item.isWishlist ? 'Busca' : 'Acepta trade por',
                  body: item.tradeLookingFor,
                ),
              ],
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CollectionInfoBlock(
                  icon: Icons.notes_rounded,
                  title: 'Nota',
                  body: item.note,
                ),
              ],
              if (item.tradeOptions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.tradeOptions
                      .map((option) => _LightTag(label: option))
                      .toList(growable: false),
                ),
              ],
              if (item.references.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CollectionInfoBlock(
                  icon: Icons.verified_user_outlined,
                  title: 'Referencias',
                  body: item.references.join(' · '),
                ),
              ],
              const SizedBox(height: 18),
              if (!isOwnItem) ...[
                FilledButton.icon(
                  key: ValueKey('collection-interest-${item.id}'),
                  onPressed: () => onInterest(primaryAction),
                  icon: Icon(
                    item.isSale
                        ? Icons.chat_bubble_outline
                        : item.isWishlist
                        ? Icons.inventory_2_outlined
                        : Icons.swap_horiz_rounded,
                  ),
                  label: Text(primaryAction),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar mensaje'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar más adelante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionInfoBlock extends StatelessWidget {
  const _CollectionInfoBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionEditorSheet extends StatefulWidget {
  const _CollectionEditorSheet({
    required this.mode,
    required this.user,
    required this.onPickImage,
  });

  final _CollectionCreateMode mode;
  final AuthUser user;
  final Future<Uint8List?> Function() onPickImage;

  @override
  State<_CollectionEditorSheet> createState() => _CollectionEditorSheetState();
}

class _CollectionEditorSheetState extends State<_CollectionEditorSheet> {
  final _titleController = TextEditingController();
  final _groupController = TextEditingController();
  final _eraController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _currencyController = TextEditingController(text: 'ARS');
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _tradeController = TextEditingController();
  final _noteController = TextEditingController();
  Uint8List? _imageBytes;
  CollectionItemCategory _category = CollectionItemCategory.photocard;
  CollectionItemStatus _status = CollectionItemStatus.inCollection;
  CollectionVisibility _visibility = CollectionVisibility.public;
  WishlistPriority _priority = WishlistPriority.medium;
  String? _error;

  @override
  void initState() {
    super.initState();
    _countryController.text = widget.user.country;
    _cityController.text = widget.user.city;
    switch (widget.mode) {
      case _CollectionCreateMode.collection:
        _status = CollectionItemStatus.inCollection;
      case _CollectionCreateMode.tradeSale:
        _status = CollectionItemStatus.availableForTrade;
      case _CollectionCreateMode.wishlist:
        _status = CollectionItemStatus.wishlist;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    _eraController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _tradeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await widget.onPickImage();
    if (!mounted || bytes == null) return;
    setState(() => _imageBytes = bytes);
  }

  void _submit() {
    final title = _titleController.text.trim();
    final group = _groupController.text.trim();
    if (title.isEmpty || group.isEmpty) {
      setState(() {
        _error = 'Completá título y grupo/artista para guardar el item.';
      });
      return;
    }
    final item = CollectionItem(
      id: 'collection-created-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: 'local-user',
      ownerName: widget.user.name,
      ownerUsername: widget.user.username,
      ownerAvatarAsset: widget.user.avatarAsset,
      imageAsset: _fallbackAssetForCategory(_category),
      imageBytes: _imageBytes,
      title: title,
      groupArtist: group,
      eraAlbum: _eraController.text.trim(),
      category: _category,
      status: _status,
      description: _descriptionController.text.trim().isEmpty
          ? 'Item agregado desde tu perfil de HallyuHub.'
          : _descriptionController.text.trim(),
      addedAt: 'Agregado ahora',
      rarity: _status == CollectionItemStatus.wishlist
          ? 'Buscado'
          : _category == CollectionItemCategory.photocard
          ? 'Standard'
          : 'Colección',
      condition: _status == CollectionItemStatus.wishlist
          ? 'Acepto buen estado'
          : 'Muy buen estado',
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      price: _status == CollectionItemStatus.forSale
          ? _priceController.text.trim()
          : '',
      currency: _status == CollectionItemStatus.forSale
          ? _currencyController.text.trim()
          : '',
      tradeLookingFor: _tradeController.text.trim(),
      tradeOptions: _status == CollectionItemStatus.availableForTrade
          ? const ['Acepto envío', 'Intercambio con referencias']
          : _status == CollectionItemStatus.forSale
          ? const ['Consulta por chat', 'Sin pagos dentro de la app']
          : const [],
      references:
          _status == CollectionItemStatus.availableForTrade ||
              _status == CollectionItemStatus.forSale
          ? const ['Referencias visibles']
          : const [],
      visibility: _visibility,
      priority: _priority,
      note: _noteController.text.trim(),
      tags: [
        '#${group.replaceAll(' ', '')}',
        '#${_category.label.replaceAll(' ', '')}',
        if (_status == CollectionItemStatus.availableForTrade) '#Trade',
        if (_status == CollectionItemStatus.forSale) '#Venta',
        if (_status == CollectionItemStatus.wishlist) '#Wishlist',
      ],
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      _CollectionCreateMode.collection => 'Agregar a colección',
      _CollectionCreateMode.tradeSale => 'Publicar trade o venta',
      _CollectionCreateMode.wishlist => 'Agregar a wishlist',
    };
    final statusOptions = switch (widget.mode) {
      _CollectionCreateMode.collection => const [
        CollectionItemStatus.inCollection,
      ],
      _CollectionCreateMode.tradeSale => const [
        CollectionItemStatus.availableForTrade,
        CollectionItemStatus.forSale,
        CollectionItemStatus.reserved,
      ],
      _CollectionCreateMode.wishlist => const [CollectionItemStatus.wishlist],
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF060913),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              const PremiumSheetHandle(),
              const SizedBox(height: 14),
              PremiumFormHero(
                title: title,
                subtitle:
                    'Organizá los datos del item y revisá todo antes de guardarlo.',
                icon: Icons.collections_bookmark_outlined,
                visual: PremiumFormVisual.profile,
                trailing: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  tooltip: 'Cerrar',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'FOTO DEL ITEM',
                style: TextStyle(
                  color: AppTheme.cyan.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              InkWell(
                key: const ValueKey('collection-pick-image'),
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.cyan.withValues(alpha: 0.34),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF10182B),
                        AppTheme.cyan.withValues(alpha: 0.12),
                        AppTheme.violet.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _imageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppTheme.cyan,
                                size: 42,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Elegir foto del item',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.rose,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'DETALLES',
                style: TextStyle(
                  color: AppTheme.violet.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              _CollectionTextField(
                key: const ValueKey('collection-title-input'),
                controller: _titleController,
                label: 'Título',
                hint: 'Ej: Jung Kook Seven photocard',
              ),
              const SizedBox(height: 10),
              _CollectionTextField(
                key: const ValueKey('collection-group-input'),
                controller: _groupController,
                label: 'Grupo / artista',
                hint: 'BTS, Stray Kids, BLACKPINK...',
              ),
              const SizedBox(height: 10),
              _CollectionTextField(
                controller: _eraController,
                label: 'Era / álbum',
                hint: 'Seven, Rock-Star, Born Pink...',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CollectionDropdown<CollectionItemCategory>(
                      label: 'Categoría',
                      value: _category,
                      values: CollectionItemCategory.values,
                      labelFor: (value) => value.label,
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CollectionDropdown<CollectionItemStatus>(
                      label: 'Estado',
                      value: _status,
                      values: statusOptions,
                      labelFor: (value) => value.label,
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              if (_status == CollectionItemStatus.forSale) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CollectionTextField(
                        controller: _priceController,
                        label: 'Precio orientativo',
                        hint: '78000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: _CollectionTextField(
                        controller: _currencyController,
                        label: 'Moneda',
                        hint: 'ARS',
                      ),
                    ),
                  ],
                ),
              ],
              if (_status == CollectionItemStatus.availableForTrade ||
                  _status == CollectionItemStatus.wishlist) ...[
                const SizedBox(height: 10),
                _CollectionTextField(
                  controller: _tradeController,
                  label: _status == CollectionItemStatus.wishlist
                      ? 'Qué ofrecés / detalle'
                      : 'Qué buscás a cambio',
                  hint: 'Ej: Jennie equivalente, trade local, refs...',
                  maxLines: 2,
                ),
              ],
              if (_status == CollectionItemStatus.wishlist) ...[
                const SizedBox(height: 10),
                _CollectionDropdown<WishlistPriority>(
                  label: 'Prioridad',
                  value: _priority,
                  values: WishlistPriority.values,
                  labelFor: (value) => value.label,
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CollectionTextField(
                      controller: _cityController,
                      label: 'Ciudad',
                      hint: 'Ciudad',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CollectionTextField(
                      controller: _countryController,
                      label: 'País',
                      hint: 'País',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CollectionTextField(
                controller: _descriptionController,
                label: 'Descripción',
                hint: 'Estado, inclusiones, condiciones de trade o nota.',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _CollectionDropdown<CollectionVisibility>(
                label: 'Visibilidad',
                value: _visibility,
                values: CollectionVisibility.values,
                labelFor: (value) => value.label,
                onChanged: (value) {
                  if (value != null) setState(() => _visibility = value);
                },
              ),
              const SizedBox(height: 10),
              _CollectionTextField(
                controller: _noteController,
                label: 'Nota privada/opcional',
                hint: 'Ej: prioridad, envío, cuidado del item...',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('collection-submit'),
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Guardar en perfil'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionTextField extends StatelessWidget {
  const _CollectionTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF0D1425),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.4),
        ),
      ),
    );
  }
}

class _CollectionDropdown<T> extends StatelessWidget {
  const _CollectionDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: AppTheme.nightSoft,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF0D1425),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      iconEnabledColor: AppTheme.cyan,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      items: values
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

class _ProfileActionSheet extends StatelessWidget {
  const _ProfileActionSheet({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<_SheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: PremiumFormShell(
            title: title,
            subtitle: subtitle,
            icon: Icons.auto_awesome_rounded,
            visual: PremiumFormVisual.create,
            child: PremiumFormSection(
              title: '¿Qué querés compartir?',
              subtitle:
                  'Cada opción conserva sus herramientas y publicación actual.',
              icon: Icons.dashboard_customize_outlined,
              children: [
                for (final action in actions)
                  PremiumActionTile(
                    key: action.key,
                    icon: action.icon,
                    color: _actionColor(action.icon),
                    title: action.title,
                    detail: action.detail,
                    onTap: action.onTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _actionColor(IconData icon) {
    if (icon == Icons.auto_stories_outlined) return AppTheme.cyan;
    if (icon == Icons.videocam_outlined) return AppTheme.violet;
    if (icon == Icons.swap_horiz_rounded) return const Color(0xFFFFB657);
    if (icon == Icons.favorite_border_rounded) return AppTheme.rose;
    if (icon == Icons.checkroom_outlined) return const Color(0xFFFF7A72);
    return AppTheme.rose;
  }
}

class _SheetAction {
  const _SheetAction({
    this.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final Key? key;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
}

class _ProfileActivity {
  const _ProfileActivity({
    required this.id,
    required this.tab,
    this.contentType,
    this.contentId = '',
    required this.profileId,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.detail,
    required this.imageAsset,
    this.imageBytes,
    this.mediaPath = '',
    this.mediaItems = const [],
    this.containsVideo = false,
    required this.badge,
    required this.tags,
    required this.stars,
    required this.comments,
    this.sharedByCommunity = false,
    this.starredByCurrentUser = false,
    this.savedByCurrentUser = false,
  });

  final String id;
  final _ProfileTab tab;
  final ProfileContentType? contentType;
  final String contentId;
  final String profileId;
  final String title;
  final String subtitle;
  final String time;
  final String detail;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final List<PostMediaItem> mediaItems;
  final bool containsVideo;
  final String badge;
  final List<String> tags;
  final String stars;
  final String comments;
  final bool sharedByCommunity;
  final bool starredByCurrentUser;
  final bool savedByCurrentUser;
}

class _ActivityMedia extends StatelessWidget {
  const _ActivityMedia({
    required this.activity,
    required this.width,
    required this.height,
  });

  final _ProfileActivity activity;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final items = activity.mediaItems.isEmpty
        ? [
            PostMediaItem(
              id: '${activity.id}-single',
              type: activity.containsVideo
                  ? PostMediaType.video
                  : PostMediaType.image,
              imageAsset: activity.imageAsset,
              imageBytes: activity.imageBytes,
              mediaPath: activity.mediaPath,
            ),
          ]
        : activity.mediaItems;
    final item = items.first;
    final mediaPath = item.mediaPath.isNotEmpty
        ? item.mediaPath
        : item.imageAsset.isEmpty
        ? activity.mediaPath
        : item.imageAsset;
    final imageAsset = item.imageAsset.isEmpty
        ? activity.imageAsset
        : item.imageAsset;
    final image = item.imageBytes != null
        ? Image.memory(
            item.imageBytes!,
            width: width,
            height: height,
            fit: BoxFit.cover,
          )
        : imageAsset.startsWith('http://') || imageAsset.startsWith('https://')
        ? Image.network(
            imageAsset,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppTheme.nightSoft,
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white70),
              ),
            ),
          )
        : Image.asset(
            imageAsset,
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            PostVideoPlayer(
              path: mediaPath,
              muted: true,
              trimStartSeconds: item.videoTrimStartSeconds,
              trimEndSeconds: item.videoTrimEndSeconds,
              fit: BoxFit.cover,
            )
          else
            image,
          if (item.isVideo)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (items.length > 1)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.collections_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoProfile {
  const _DemoProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.city,
    required this.country,
    required this.fandom,
    required this.favoriteGroup,
    required this.bio,
    required this.avatarAsset,
    required this.coverAsset,
    required this.posts,
    required this.followers,
    required this.following,
    required this.stars,
    required this.level,
    required this.colors,
    this.online = false,
  });

  factory _DemoProfile.fromCommunity(CommunityProfile profile) {
    return _DemoProfile(
      id: profile.id,
      name: profile.name,
      username: profile.username,
      city: profile.city,
      country: profile.country,
      fandom: profile.fandom,
      favoriteGroup: profile.favoriteGroup,
      bio: profile.bio,
      avatarAsset: profile.avatarAsset,
      coverAsset: profile.coverAsset,
      posts: profile.posts,
      followers: profile.followers,
      following: profile.following,
      stars: profile.starsReceived,
      level: profile.level,
      colors: [...profile.colors, AppTheme.night],
      online: profile.online,
    );
  }

  final String id;
  final String name;
  final String username;
  final String city;
  final String country;
  final String fandom;
  final String favoriteGroup;
  final String bio;
  final String avatarAsset;
  final String coverAsset;
  final String posts;
  final String followers;
  final String following;
  final String stars;
  final int level;
  final List<Color> colors;
  final bool online;
}

// ignore: unused_element
class _PersonProfileSheet extends StatelessWidget {
  const _PersonProfileSheet({
    required this.profile,
    required this.following,
    required this.onFollow,
    required this.onMessage,
    required this.onViewPosts,
    required this.onOpenStat,
    required this.onOpenInterest,
    required this.onShare,
    required this.collectionItems,
    required this.onOpenCollectionItem,
  });

  final _DemoProfile profile;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onViewPosts;
  final ValueChanged<String> onOpenStat;
  final ValueChanged<String> onOpenInterest;
  final VoidCallback onShare;
  final List<CollectionItem> collectionItems;
  final ValueChanged<CollectionItem> onOpenCollectionItem;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Compartir perfil',
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: profile.colors,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    HubAvatar(
                      asset: profile.avatarAsset,
                      size: 92,
                      isLive: profile.online,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _communityProfileSubtitle(profile),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatGrid(
                      keyPrefix: 'person-${profile.id}',
                      onTap: onOpenStat,
                      stats: [
                        ProfileStat(profile.posts, 'posts'),
                        ProfileStat(profile.followers, 'seguidores'),
                        ProfileStat(profile.following, 'siguiendo'),
                        ProfileStat(profile.stars, 'estrellas'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FandomStrip(
                      keyPrefix: 'person-${profile.id}',
                      onTap: onOpenInterest,
                      labels: [
                        profile.fandom,
                        profile.favoriteGroup,
                        'Nivel ${profile.level}',
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onFollow,
                      icon: Icon(
                        following ? Icons.check : Icons.person_add_alt_1,
                      ),
                      label: Text(following ? 'Siguiendo' : 'Seguir'),
                      style: FilledButton.styleFrom(
                        backgroundColor: following
                            ? Colors.white.withValues(alpha: 0.16)
                            : AppTheme.rose,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Mensaje'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onViewPosts,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Ver publicaciones'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
              if (collectionItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PublicCollectionPreview(
                  ownerName: profile.name,
                  items: collectionItems,
                  onOpen: onOpenCollectionItem,
                ),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  profile.coverAsset,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionsSheet extends StatefulWidget {
  const _ConnectionsSheet({
    required this.title,
    required this.subtitle,
    required this.profiles,
    required this.followedProfiles,
    required this.onOpen,
    required this.onFollow,
  });

  final String title;
  final String subtitle;
  final List<_DemoProfile> profiles;
  final Set<String> followedProfiles;
  final ValueChanged<_DemoProfile> onOpen;
  final ValueChanged<_DemoProfile> onFollow;

  @override
  State<_ConnectionsSheet> createState() => _ConnectionsSheetState();
}

class _ConnectionsSheetState extends State<_ConnectionsSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.profiles.where((profile) {
      if (query.isEmpty) return true;
      final initials = profile.name
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0])
          .join()
          .toLowerCase();
      return profile.name.toLowerCase().contains(query) ||
          profile.username.toLowerCase().contains(query) ||
          initials.contains(query);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: const BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('connections-search'),
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, usuario o iniciales',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.cyan),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No encontramos perfiles con esa búsqueda.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final profile = filtered[index];
                          final following = widget.followedProfiles.contains(
                            profile.id,
                          );
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              key: ValueKey('connection-${profile.id}'),
                              contentPadding: EdgeInsets.zero,
                              onTap: () => widget.onOpen(profile),
                              leading: HubAvatar(
                                asset: profile.avatarAsset,
                                size: 46,
                                isLive: profile.online,
                              ),
                              title: Text(
                                profile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${profile.username} · ${profile.fandom}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.56),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: () {
                                  widget.onFollow(profile);
                                  setState(() {});
                                },
                                child: Text(following ? 'Siguiendo' : 'Seguir'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PersonPostsSheet extends StatelessWidget {
  const _PersonPostsSheet({
    required this.profile,
    required this.activities,
    required this.onShare,
  });

  final _DemoProfile profile;
  final List<_ProfileActivity> activities;
  final ValueChanged<_ProfileActivity> onShare;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: const BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  HubAvatar(
                    asset: profile.avatarAsset,
                    size: 48,
                    isLive: profile.online,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publicaciones de ${profile.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          profile.username,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: activities.isEmpty
                    ? Center(
                        child: Text(
                          'Este perfil todavía no tiene publicaciones visibles.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: activities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _ActivityMedia(
                                    activity: activity,
                                    width: 78,
                                    height: 78,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activity.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${activity.stars} estrellas · ${activity.comments} comentarios',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.58,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => onShare(activity),
                                  icon: const Icon(Icons.share_outlined),
                                  color: Colors.white,
                                  tooltip: 'Compartir',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FanProgress {
  const _FanProgress({
    required this.level,
    required this.stars,
    required this.percent,
  });

  final int level;
  final int stars;
  final double percent;
}

Color _collectionStatusColor(CollectionItemStatus status) {
  switch (status) {
    case CollectionItemStatus.inCollection:
      return AppTheme.cyan;
    case CollectionItemStatus.availableForTrade:
      return AppTheme.violet;
    case CollectionItemStatus.forSale:
      return AppTheme.amber;
    case CollectionItemStatus.reserved:
      return AppTheme.indigo;
    case CollectionItemStatus.sold:
      return AppTheme.mutedInk;
    case CollectionItemStatus.wishlist:
      return AppTheme.rose;
  }
}

IconData _collectionCategoryIcon(CollectionItemCategory category) {
  switch (category) {
    case CollectionItemCategory.photocard:
      return Icons.style_outlined;
    case CollectionItemCategory.album:
      return Icons.album_outlined;
    case CollectionItemCategory.lightstick:
      return Icons.flashlight_on_outlined;
    case CollectionItemCategory.merch:
      return Icons.shopping_bag_outlined;
    case CollectionItemCategory.fanmade:
      return Icons.brush_outlined;
    case CollectionItemCategory.poster:
      return Icons.wallpaper_outlined;
    case CollectionItemCategory.other:
      return Icons.inventory_2_outlined;
  }
}

String _fallbackAssetForCategory(CollectionItemCategory category) {
  switch (category) {
    case CollectionItemCategory.photocard:
      return 'assets/demo-posts/post-09.jpg';
    case CollectionItemCategory.album:
      return 'assets/demo-posts/post-05.jpg';
    case CollectionItemCategory.lightstick:
      return 'assets/demo-posts/post-12.jpg';
    case CollectionItemCategory.merch:
      return 'assets/demo-posts/post-08.jpg';
    case CollectionItemCategory.fanmade:
      return 'assets/demo-posts/post-07.jpg';
    case CollectionItemCategory.poster:
      return 'assets/demo-posts/post-02.jpg';
    case CollectionItemCategory.other:
      return 'assets/demo-posts/post-01.jpg';
  }
}

final _communityProfiles = demoProfiles
    .map(_DemoProfile.fromCommunity)
    .toList(growable: false);

_DemoProfile _profileById(String id) {
  return _communityProfiles.firstWhere(
    (profile) => profile.id == id,
    orElse: () => _communityProfiles.first,
  );
}

List<_DemoProfile> _followersFor(_DemoProfile? owner) {
  if (owner == null) return _communityProfiles;
  return _communityProfiles
      .where((profile) => profile.id != owner.id)
      .toList(growable: false);
}

List<_DemoProfile> _followingFor(_DemoProfile? owner) {
  final profiles = _followersFor(owner);
  return profiles.take(profiles.length > 2 ? 2 : profiles.length).toList();
}

List<ShareRecipient> _shareRecipientsFor(List<_DemoProfile> profiles) {
  return profiles
      .map(
        (profile) => ShareRecipient(
          id: profile.id,
          name: profile.name,
          username: profile.username,
          avatarAsset: profile.avatarAsset,
        ),
      )
      .toList(growable: false);
}

int _parseCompactCount(String value) {
  final normalized = value.trim().toUpperCase();
  final multiplier = normalized.endsWith('K')
      ? 1000
      : normalized.endsWith('M')
      ? 1000000
      : 1;
  final number = double.tryParse(normalized.replaceAll(RegExp(r'[^0-9.]'), ''));
  return ((number ?? 0) * multiplier).round();
}

String _formatCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return '$value';
}

_FanProgress _fanProgress(int stars) {
  const starsPerLevel = 5000;
  final level = stars ~/ starsPerLevel + 1;
  final currentLevelStars = stars % starsPerLevel;
  final remainingStars = starsPerLevel - currentLevelStars;
  final percent = currentLevelStars / starsPerLevel;
  return _FanProgress(level: level, stars: remainingStars, percent: percent);
}

List<Color> _profileBackgroundColors(String background) {
  switch (background) {
    case 'Stage violet':
      return const [Color(0xFF4C6FFF), Color(0xFFA855F7), AppTheme.night];
    case 'Lightstick cyan':
      return const [Color(0xFF07181C), Color(0xFF65E4FF), AppTheme.night];
    case 'Comeback rose':
      return const [Color(0xFFEF4F7A), Color(0xFFFFB703), AppTheme.night];
    case 'Midnight aurora':
      return const [Color(0xFF080311), Color(0xFF00A6A6), AppTheme.night];
    default:
      return const [Color(0xFFEF4F7A), Color(0xFF65E4FF), AppTheme.night];
  }
}

bool _isDemoProfile(AuthUser user) {
  return user.email.endsWith('@hallyuhub.local');
}

String _communityProfileSubtitle(_DemoProfile profile) {
  final city = profile.city.trim();
  final country = profile.country.trim();
  final location = [
    if (city.isNotEmpty) city,
    if (country.isNotEmpty && country != city) country,
  ].join(', ');
  return location.isEmpty
      ? profile.username
      : '${profile.username} · $location';
}

List<_ProfileActivity> _profileActivities(AuthUser user) {
  if (!_isDemoProfile(user)) return const [];
  return [
    _ProfileActivity(
      id: 'post-lookbook',
      tab: _ProfileTab.posts,
      profileId: 'demo-luna',
      title: 'Moodboard comeback',
      subtitle: '${user.favoriteGroup} · hace 20 min',
      time: 'Ahora',
      detail: 'Publicación con inspiración visual, playlist y agenda fandom.',
      imageAsset: 'assets/demo-posts/post-02.jpg',
      badge: 'Post',
      tags: ['#${user.favoriteGroup}', '#HallyuHub', '#Comeback'],
      stars: '12.8K',
      comments: '384',
    ),
    const _ProfileActivity(
      id: 'post-event',
      tab: _ProfileTab.posts,
      profileId: 'demo-cami',
      title: 'Encuentro fandom pastel',
      subtitle: 'Santiago · ayer',
      time: 'Ayer',
      detail: 'Fotos, freebies y organización de comunidad.',
      imageAsset: 'assets/demo-posts/post-01.jpg',
      badge: 'Evento',
      tags: ['#KpopLatam', '#Evento', '#Photocards'],
      stars: '9.4K',
      comments: '216',
      sharedByCommunity: true,
    ),
    const _ProfileActivity(
      id: 'drop-dance',
      tab: _ProfileTab.drops,
      profileId: 'demo-agus',
      title: 'Random play dance',
      subtitle: 'Drop vertical · hace 1 h',
      time: 'Hace 1 h',
      detail: 'Challenge con transición de luces y coreografía corta.',
      imageAsset: 'assets/demo-posts/post-03.jpg',
      badge: 'Drop',
      tags: ['#DanceChallenge', '#Drops'],
      stars: '68K',
      comments: '1.2K',
    ),
    const _ProfileActivity(
      id: 'fancam-stage',
      tab: _ProfileTab.fancams,
      profileId: 'demo-renata',
      title: 'Main dancer focus',
      subtitle: 'Fancam · 00:48',
      time: '00:48',
      detail: 'Video enfocado en performance y energía del escenario.',
      imageAsset: 'assets/demo-posts/post-11.jpg',
      badge: 'Fancam',
      tags: ['#Fancam', '#Stage', '#4K'],
      stars: '42K',
      comments: '820',
      sharedByCommunity: true,
    ),
    const _ProfileActivity(
      id: 'photocard-trade',
      tab: _ProfileTab.photocards,
      profileId: 'demo-cami',
      title: 'Wishlist actualizada',
      subtitle: 'Trade meet · esta semana',
      time: 'Esta semana',
      detail: 'Carpeta de colección, sleeves y prioridades de intercambio.',
      imageAsset: 'assets/demo-posts/post-09.jpg',
      badge: 'Photocard',
      tags: ['#TradeSeguro', '#Wishlist'],
      stars: '4.6K',
      comments: '96',
    ),
    const _ProfileActivity(
      id: 'outfit-stage',
      tab: _ProfileTab.outfit,
      profileId: 'demo-luna',
      title: 'Outfit pastel neon',
      subtitle: 'Stage fit · próximo evento',
      time: 'Hace 3 h',
      detail: 'Look armado para random dance con capas suaves y brillo sutil.',
      imageAsset: 'assets/demo-posts/post-10.jpg',
      badge: 'Outfit',
      tags: ['#KpopOutfit', '#PastelNeon', '#DanceCover'],
      stars: '14.3K',
      comments: '302',
    ),
    const _ProfileActivity(
      id: 'guide-stream',
      tab: _ProfileTab.posts,
      profileId: 'demo-renata',
      title: 'Guía comeback',
      subtitle: 'Guardado por la comunidad',
      time: 'Guardado',
      detail: 'Horarios, votaciones, streaming y checklist fan.',
      imageAsset: 'assets/demo-posts/post-06.jpg',
      badge: 'Guía',
      tags: ['#Kpop101', '#Guía'],
      stars: '21K',
      comments: '512',
      sharedByCommunity: true,
    ),
  ];
}
