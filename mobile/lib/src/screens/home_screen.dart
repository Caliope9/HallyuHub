import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/demo_data.dart';
import '../models.dart';
import '../screens/camera_capture_screen.dart';
import '../screens/kpop_entity_profile_screen.dart';
import '../screens/post_editor_screen.dart';
import '../screens/public_profile_screen.dart';
import '../screens/story_editor_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/media_permission_service.dart';
import '../services/share_links.dart';
import '../services/story_time.dart';
import '../services/store_profile_service.dart';
import '../services/video_audio_preference.dart';
import '../theme/app_theme.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/contextual_permission_sheet.dart';
import '../widgets/hallyu_post_card.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/premium_form_shell.dart';
import '../widgets/share_sheet.dart';
import '../widgets/safety_report_sheet.dart';
import '../widgets/story_composer_sheet.dart';
import '../services/local_follow_service.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.storyService = const LocalStoryService(),
    this.postService = const LocalPostService(),
    this.followService = const LocalFollowService(),
    this.chatService = const LocalChatService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.user,
    this.resetSignal = 0,
  });

  final LocalStoryService storyService;
  final LocalPostService postService;
  final LocalFollowService followService;
  final LocalChatService chatService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;
  final AuthUser? user;
  final int resetSignal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final Set<String> _likedPosts = {};
  final Set<String> _savedPosts = {};
  final Set<String> _updatingLikes = {};
  final Set<String> _updatingSaves = {};
  final Set<String> _sharedPosts = {};
  final Set<String> _followedSuggestions = {};
  final Set<String> _followedEntityIds = {};
  final Set<String> _starredStories = {};
  final Set<String> _viewedStoryIds = {};
  final Set<String> _blockedUserIds = {};
  final Map<String, int> _commentAdditions = {};
  final Map<String, List<String>> _storyReplies = {};
  final List<Story> _ownStories = [];
  final List<Story> _followingStories = [];
  final List<HubPost> _localPosts = [];
  final List<CommunityProfile> _suggestedProfiles = [];
  final List<CommunityProfile> _knownProfiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  final MediaPermissionService _permissionService =
      const MediaPermissionService();
  late final Map<String, List<PostComment>> _commentsByPost = {
    for (final entry in postComments.entries) entry.key: [...entry.value],
  };
  bool _videosMuted = true;
  static const _feedPageSize = 12;
  int _feedOffset = 0;
  bool _feedLoading = false;
  bool _feedHasMore = true;

  @override
  void initState() {
    super.initState();
    LocalStoryService.revision.addListener(_reloadOwnStories);
    LocalPostService.revision.addListener(_reloadPosts);
    LocalFollowService.revision.addListener(_reloadFollowing);
    LocalSafetyService.revision.addListener(_reloadSafety);
    VideoAudioPreference.muted.addListener(_syncVideoAudioPreference);
    _scrollController.addListener(_handleFeedScroll);
    _videosMuted = VideoAudioPreference.muted.value;
    _restoreStoryState();
    _restoreFollowing();
    _restoreSafety();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleFeedScroll);
    _scrollController.dispose();
    LocalStoryService.revision.removeListener(_reloadOwnStories);
    LocalPostService.revision.removeListener(_reloadPosts);
    LocalFollowService.revision.removeListener(_reloadFollowing);
    LocalSafetyService.revision.removeListener(_reloadSafety);
    VideoAudioPreference.muted.removeListener(_syncVideoAudioPreference);
    super.dispose();
  }

  void _syncVideoAudioPreference() {
    if (!mounted) return;
    setState(() => _videosMuted = VideoAudioPreference.muted.value);
  }

  void _handleFeedScroll() {
    if (!widget.postService.usesRealPosts ||
        _feedLoading ||
        !_feedHasMore ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 720) {
      _restorePosts(reset: false);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) _resetToTop();
  }

  void _resetToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _reloadOwnStories() {
    _restoreStoryState();
  }

  void _reloadPosts() {
    _restorePosts();
  }

  void _reloadFollowing() {
    _restoreFollowing();
  }

  void _reloadSafety() {
    _restoreSafety();
  }

  Future<void> _restoreSafety() async {
    try {
      final blocked = await widget.safetyService.restoreBlockedUserIds();
      if (!mounted) return;
      setState(() {
        _blockedUserIds
          ..clear()
          ..addAll(blocked);
      });
    } catch (error) {
      debugPrint('SAFETY_HOME_ERROR restore error=$error');
    }
  }

  Future<void> _restoreFollowing() async {
    var following = <String>{};
    var followedEntities = <String>{};
    var profiles = <CommunityProfile>[];
    try {
      following = await widget.followService.restoreFollowingIds();
    } catch (error) {
      debugPrint('FOLLOW_HOME_ERROR ids error=$error');
    }
    if (widget.followService.usesRealProfiles) {
      followedEntities = await _restoreFollowedEntityIds();
    }
    try {
      profiles = await widget.followService.restoreProfiles(limit: 80);
    } catch (error) {
      debugPrint('FOLLOW_HOME_ERROR profiles error=$error');
    }
    final knownProfiles = profiles
        .where((profile) => !_blockedUserIds.contains(profile.id))
        .toList(growable: false);
    final orderedProfiles = knownProfiles
        .where(
          (profile) =>
              !_blockedUserIds.contains(profile.id) &&
              !following.contains(profile.id),
        )
        .toList();
    if (widget.followService.usesRealProfiles) {
      orderedProfiles.sort((a, b) {
        final aFollowed = following.contains(a.id);
        final bFollowed = following.contains(b.id);
        if (aFollowed == bFollowed) return 0;
        return aFollowed ? 1 : -1;
      });
    }
    if (!mounted) return;
    setState(() {
      _followedSuggestions
        ..clear()
        ..addAll(following);
      _followedEntityIds
        ..clear()
        ..addAll(followedEntities);
      _knownProfiles
        ..clear()
        ..addAll(knownProfiles);
      _suggestedProfiles
        ..clear()
        ..addAll(orderedProfiles.take(12));
    });
    await _restoreStoryState();
    await _restorePosts(reset: true);
  }

  Future<Set<String>> _restoreFollowedEntityIds() async {
    try {
      final client = supabase.Supabase.instance.client;
      final authUser = client.auth.currentUser;
      if (authUser == null) return <String>{};
      final rows = await client
          .from('kpop_entity_follows')
          .select('entity_id')
          .eq('user_id', authUser.id);
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) => row['entity_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('HOME_ENTITY_FOLLOWS_ERROR $error');
      return <String>{};
    }
  }

  Future<void> _restorePosts({bool reset = true}) async {
    if (_feedLoading) return;
    List<HubPost> restoredPosts;
    Set<String> likedPostIds;
    Set<String> savedPostIds;
    final stopwatch = Stopwatch()..start();
    final offset = reset || !widget.postService.usesRealPosts ? 0 : _feedOffset;
    _logPerformance('PERF_HOME_POSTS_START reset=$reset offset=$offset');
    _feedLoading = true;
    try {
      restoredPosts = await widget.postService.restorePosts(
        limit: widget.postService.usesRealPosts ? _feedPageSize : 60,
        offset: offset,
        homeFeed:
            widget.postService.usesRealPosts &&
            widget.followService.usesRealProfiles,
        followedAuthorIds: _followedSuggestions,
        followedEntityIds: _followedEntityIds,
      );
      likedPostIds = await widget.postService.restoreLikedPostIds();
      savedPostIds = await widget.postService.restoreSavedPostIds();
    } catch (_) {
      restoredPosts = const [];
      likedPostIds = const {};
      savedPostIds = const {};
    }
    _feedLoading = false;
    _logPerformance(
      'PERF_HOME_POSTS_OK count=${restoredPosts.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    if (!mounted) return;
    final nextPosts = reset
        ? restoredPosts
        : [
            ..._localPosts,
            ...restoredPosts.where(
              (post) => !_localPosts.any((current) => current.id == post.id),
            ),
          ];
    setState(() {
      if (widget.postService.usesRealPosts) {
        _feedOffset = reset
            ? restoredPosts.length
            : _feedOffset + restoredPosts.length;
        _feedHasMore = restoredPosts.length == _feedPageSize;
      } else {
        _feedOffset = restoredPosts.length;
        _feedHasMore = false;
      }
      _localPosts
        ..clear()
        ..addAll(nextPosts);
      _likedPosts
        ..clear()
        ..addAll(likedPostIds)
        ..addAll(
          restoredPosts
              .where((post) => post.likedByCurrentUser)
              .map((post) => post.id),
        );
      _savedPosts
        ..clear()
        ..addAll(savedPostIds)
        ..addAll(
          restoredPosts
              .where((post) => post.savedByCurrentUser)
              .map((post) => post.id),
        );
    });
  }

  Future<void> _restoreStoryState() async {
    List<Story> restoredStories;
    List<Story> followingStories;
    Set<String> viewedStoryIds;
    Set<String> starredStoryIds;
    try {
      restoredStories = await widget.storyService.restoreOwnStories();
      followingStories = await widget.storyService.restoreFollowingStories(
        followingIds: _followedSuggestions,
      );
      viewedStoryIds = await widget.storyService.restoreViewedStoryIds();
      starredStoryIds = await widget.storyService.restoreStarredStoryIds();
    } catch (_) {
      restoredStories = const [];
      followingStories = const [];
      viewedStoryIds = const {};
      starredStoryIds = const {};
    }
    if (!mounted) return;
    setState(() {
      _ownStories
        ..clear()
        ..addAll(restoredStories);
      _followingStories
        ..clear()
        ..addAll(followingStories);
      _viewedStoryIds
        ..clear()
        ..addAll(viewedStoryIds);
      _starredStories
        ..clear()
        ..addAll(starredStoryIds);
    });
  }

  List<PostComment> _commentsFor(HubPost post) =>
      _commentsByPost.putIfAbsent(post.id, () => []);

  Future<void> _toggleLike(HubPost post) async {
    if (_updatingLikes.contains(post.id)) return;
    final wasLiked = _likedPosts.contains(post.id);
    final nextLiked = !wasLiked;
    setState(() {
      _updatingLikes.add(post.id);
      if (nextLiked) {
        _likedPosts.add(post.id);
      } else {
        _likedPosts.remove(post.id);
      }
    });
    try {
      await widget.postService.setPostLiked(post.id, nextLiked);
      if (!mounted) return;
      _showSnack(nextLiked ? 'Estrella agregada' : 'Estrella quitada');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedPosts.add(post.id);
        } else {
          _likedPosts.remove(post.id);
        }
      });
      _showSnack('No pudimos actualizar la estrella. Probá otra vez.');
    } finally {
      if (mounted) {
        setState(() => _updatingLikes.remove(post.id));
      }
    }
  }

  Future<void> _toggleSave(HubPost post) async {
    if (_updatingSaves.contains(post.id)) return;
    final wasSaved = _savedPosts.contains(post.id);
    final nextSaved = !wasSaved;
    setState(() {
      _updatingSaves.add(post.id);
      if (nextSaved) {
        _savedPosts.add(post.id);
      } else {
        _savedPosts.remove(post.id);
      }
    });
    try {
      await widget.postService.setPostSaved(post.id, nextSaved);
      if (!mounted) return;
      _showSnack(nextSaved ? 'Post guardado' : 'Guardado quitado');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedPosts.add(post.id);
        } else {
          _savedPosts.remove(post.id);
        }
      });
      _showSnack('No pudimos actualizar el guardado. Probá otra vez.');
    } finally {
      if (mounted) {
        setState(() => _updatingSaves.remove(post.id));
      }
    }
  }

  bool _isServicePost(HubPost post) =>
      _localPosts.any((servicePost) => servicePost.id == post.id);

  Future<void> _openComments(HubPost post) async {
    final servicePost = _isServicePost(post);
    List<PostComment> initialComments;
    try {
      initialComments = servicePost
          ? await widget.postService.restoreComments(post.id)
          : _commentsFor(post);
    } on PostServiceException catch (error) {
      if (error.message.contains('no está disponible')) {
        if (mounted) {
          setState(() => _localPosts.removeWhere((item) => item.id == post.id));
          _showSnack(error.message);
        }
        return;
      }
      initialComments = _commentsFor(post);
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      initialComments = _commentsFor(post);
      if (mounted) _showSnack('No pudimos cargar comentarios reales.');
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => CommentsSheet(
        threadId: post.id,
        subtitle: post.author,
        initialComments: initialComments,
        currentUserName: widget.user?.name ?? 'Tu perfil',
        currentUsername: widget.user?.username ?? '@mika.hallyu',
        currentUserAvatar:
            widget.user?.avatarAsset ?? 'assets/demo-users/user-01.jpg',
        safetyService: widget.safetyService,
        reportContentType: 'comment',
        onSubmitComment: servicePost
            ? (body, parentId) => widget.postService.addComment(
                author: widget.user ?? _fallbackPostAuthor,
                postId: post.id,
                body: body,
                parentId: parentId,
              )
            : null,
        onDeleteComment: servicePost
            ? (comment) => widget.postService.deleteComment(
                postId: post.id,
                commentId: comment.id,
              )
            : null,
        onOpenAuthor: _openCommentAuthor,
        onChanged: (comments) {
          setState(() {
            _commentsByPost[post.id] = comments;
          });
        },
        onCommentAdded: () {
          if (servicePost) return;
          setState(() {
            _commentAdditions.update(
              post.id,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          });
        },
        onCommentsRemoved: (count) {
          if (servicePost) return;
          setState(() {
            _commentAdditions.update(
              post.id,
              (value) => (value - count).clamp(0, 999999),
              ifAbsent: () => 0,
            );
          });
        },
      ),
    );
  }

  Future<void> _toggleSuggestionFollow(CommunityProfile profile) async {
    final wasFollowing = _followedSuggestions.contains(profile.id);
    final previousSuggestions = List<CommunityProfile>.of(_suggestedProfiles);
    setState(() {
      if (wasFollowing) {
        _followedSuggestions.remove(profile.id);
      } else {
        _followedSuggestions.add(profile.id);
        _suggestedProfiles.removeWhere((item) => item.id == profile.id);
      }
    });
    try {
      final nowFollowing = await widget.followService.toggleFollowing(
        profile.id,
      );
      if (!mounted) return;
      setState(() {
        if (nowFollowing) {
          _followedSuggestions.add(profile.id);
          _suggestedProfiles.removeWhere((item) => item.id == profile.id);
        } else {
          _followedSuggestions.remove(profile.id);
        }
      });
      _showSnack(
        nowFollowing
            ? 'Ahora sigues a ${profile.name}'
            : 'Dejaste de seguir a ${profile.name}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestedProfiles
          ..clear()
          ..addAll(previousSuggestions);
        if (wasFollowing) {
          _followedSuggestions.add(profile.id);
        } else {
          _followedSuggestions.remove(profile.id);
        }
      });
      _showSnack('No pudimos actualizar el seguimiento. Probá otra vez.');
    }
  }

  void _openSuggestion(CommunityProfile profile) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          profile: profile,
          currentUser: widget.user,
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

  Future<void> _openTaggedUsername(String username) async {
    final query = username.replaceFirst('@', '').trim();
    if (query.isEmpty) return;
    try {
      final profiles = await widget.followService.restoreProfiles(
        query: query,
        limit: 12,
      );
      final normalized = query.toLowerCase();
      final profile = profiles.firstWhere(
        (profile) =>
            profile.username.replaceFirst('@', '').toLowerCase().trim() ==
            normalized,
        orElse: () =>
            profiles.isEmpty ? throw StateError('missing') : profiles.first,
      );
      if (!mounted) return;
      _openSuggestion(profile);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No encontramos ese perfil.');
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
      _openSuggestion(resolved);
      return;
    }
    final profile = CommunityProfile(
      id: comment.authorId.isEmpty ? comment.username : comment.authorId,
      name: comment.author,
      username: comment.username,
      city: '',
      country: '',
      fandom: '',
      favoriteGroup: '',
      bio: '',
      avatarAsset: comment.avatarAsset,
      followers: '',
      posts: '',
      colors: const [AppTheme.cyan, AppTheme.rose, AppTheme.night],
    );
    _openSuggestion(profile);
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
      debugPrint('COMMENT_AUTHOR_PROFILE_RESOLVE_ERROR $error');
      return null;
    }
  }

  void _openHomeFeature(String title, String detail) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeatureSheet(title: title, detail: detail),
    );
  }

  void _openStory(Story story) {
    final orderedStories = _orderedFollowingStories;
    final firstPending = orderedStories.indexWhere(
      (candidate) =>
          candidate.authorId == story.authorId &&
          !_viewedStoryIds.contains(candidate.id),
    );
    _pushStoryViewer(
      orderedStories,
      firstPending == -1 ? orderedStories.indexOf(story) : firstPending,
    );
  }

  List<Story> get _orderedFollowingStories {
    final groups = <String, List<Story>>{};
    for (final story in _followingStories) {
      if (!widget.storyService.usesRealStories &&
          !_followedSuggestions.contains(story.authorId)) {
        continue;
      }
      groups.putIfAbsent(story.authorId, () => []).add(story);
    }
    final orderedGroups = groups.values.toList()
      ..sort((a, b) {
        final aViewed = a.every((story) => _viewedStoryIds.contains(story.id));
        final bViewed = b.every((story) => _viewedStoryIds.contains(story.id));
        if (aViewed != bViewed) return aViewed ? 1 : -1;
        return compareStoryRecency(_mostRecentStory(a), _mostRecentStory(b));
      });
    return orderedGroups.expand((group) => group).toList(growable: false);
  }

  Story _mostRecentStory(List<Story> stories) {
    return stories.reduce(
      (current, candidate) =>
          compareStoryRecency(current, candidate) <= 0 ? current : candidate,
    );
  }

  List<ShareRecipient> get _realAwareShareRecipients {
    if (!widget.followService.usesRealProfiles) return _shareRecipients;
    return _knownProfiles
        .where((profile) => _followedSuggestions.contains(profile.id))
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

  void _openOwnStories() {
    if (_ownStories.isEmpty) {
      _openStoryCreator();
      return;
    }
    _pushStoryViewer(_ownStories, 0);
  }

  void _pushStoryViewer(List<Story> visibleStories, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StoryViewerScreen(
          stories: visibleStories,
          initialIndex: initialIndex,
          recipients: _realAwareShareRecipients,
          starredStoryIds: _starredStories,
          onViewed: _markStoryViewed,
          onToggleStar: _toggleStoryStar,
          onReply: (story, message) {
            setState(() {
              _storyReplies.putIfAbsent(story.id, () => []).add(message);
            });
          },
          onDelete: _deleteStory,
          currentUser: widget.user,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          chatService: widget.chatService,
          safetyService: widget.safetyService,
        ),
      ),
    );
  }

  void _openStoryCreator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StoryComposerSheet(
        templates: storyTemplates,
        onPublish: (draft) => _openStoryEditorFromSheet(sheetContext, draft),
        onCamera: () =>
            _pickStoryEditorSource(sheetContext, ImageSource.camera),
        onGallery: () =>
            _pickStoryEditorSource(sheetContext, ImageSource.gallery),
      ),
    );
  }

  void _openCreateContentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _HomeCreateContentSheet(
        onStory: () {
          Navigator.of(sheetContext).pop();
          _openStoryCreator();
        },
        onPost: () {
          Navigator.of(sheetContext).pop();
          _openPostEditor();
        },
      ),
    );
  }

  Future<void> _openPostEditor() async {
    final draft = await Navigator.of(context).push<PostDraft>(
      MaterialPageRoute<PostDraft>(
        fullscreenDialog: true,
        builder: (context) => PostEditorScreen(
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
      post = await widget.postService.publish(
        author: widget.user ?? _fallbackPostAuthor,
        draft: draft,
      );
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
    if (categoriesSaved) {
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
      _showSnack('Publicación agregada a Inicio y a tu perfil');
    }
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
      debugPrint('CONTENT_USER_TAGS_SAVE_ERROR $contentType/$contentId $error');
      if (!mounted) return;
      _showSnack('Se publicó, pero no pudimos guardar todas las etiquetas.');
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
        'CONTENT_ARTIST_TAGS_SAVE_ERROR home $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack('Se publicó, pero no pudimos guardar artistas etiquetados.');
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
      debugPrint(
        'CONTENT_CATEGORY_ERROR home contentId=$contentId error=$error',
      );
      if (mounted) {
        _showSnack(
          'Publicado. No pudimos guardarlo en los globitos del perfil todavía.',
        );
      }
      return false;
    }
    return true;
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
        ),
      );
  }

  void _toggleVideoSound() {
    final nextMuted = !_videosMuted;
    VideoAudioPreference.setMuted(nextMuted, source: 'home');
    _showSnack(
      nextMuted
          ? 'Todos los videos quedan silenciados'
          : 'Audio activado para todos los videos',
    );
  }

  void _markStoryViewed(Story story) {
    if (!_viewedStoryIds.add(story.id)) return;
    if (mounted) setState(() {});
    widget.storyService.saveViewedStoryIds(_viewedStoryIds);
  }

  void _toggleStoryStar(Story story) {
    setState(() {
      if (!_starredStories.add(story.id)) {
        _starredStories.remove(story.id);
      }
    });
    widget.storyService.saveStarredStoryIds(_starredStories);
  }

  Future<void> _publishStoryDraft(StoryDraft draft) async {
    _showUploadStatus('Publicando historia...');
    Story story;
    try {
      story = await widget.storyService.publish(
        author: widget.user ?? _fallbackPostAuthor,
        draft: draft,
        currentStories: _ownStories,
        viewers: widget.storyService.usesRealStories
            ? const []
            : demoStoryViewers,
        views: widget.storyService.usesRealStories ? 0 : 37,
        stars: widget.storyService.usesRealStories
            ? 0
            : demoStoryViewers.where((viewer) => viewer.starred).length,
      );
      await _restoreStoryState();
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
    _showSnack('Historia publicada');
    _openOwnStories();
  }

  Future<void> _deleteStory(Story story) async {
    try {
      await widget.storyService.deleteStory(story.id);
      await _restoreStoryState();
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos borrar la historia.');
      rethrow;
    }
    if (!mounted) return;
    _showSnack('Historia eliminada');
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
        ),
      ),
    );
    if (!mounted || edited == null) return;
    await _publishStoryDraft(edited);
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

  void _openShare(HubPost post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppShareSheet(
        title: 'Compartir publicación',
        subtitle: post.caption,
        shareText: '${post.caption}\n${ShareLinks.publication(post.id)}',
        recipients: _realAwareShareRecipients,
        onSelected: (label) {
          Navigator.of(sheetContext).pop();
          setState(() => _sharedPosts.add(post.id));
          _showSnack(label);
        },
        onShareToStory: () async {
          Navigator.of(sheetContext).pop();
          await _openStoryEditor(
            StoryDraft(
              type: StoryContentType.text,
              title: 'Contenido compartido',
              detail: post.caption,
              text: 'Ver publicación de ${post.author}',
              sharedContentType: 'post',
              sharedContentId: post.id,
            ),
          );
        },
      ),
    );
  }

  void _openProfile(HubPost post) {
    _openSuggestion(
      CommunityProfile(
        id: post.authorId.isEmpty ? post.username : post.authorId,
        name: post.author,
        username: post.username,
        city: post.location,
        country: '',
        fandom: post.artist.isEmpty ? 'HallyuHub' : post.artist,
        favoriteGroup: post.artist,
        bio: 'Compartiendo publicaciones en HallyuHub.',
        avatarAsset: post.avatarAsset,
        followers: '',
        posts: '',
        colors: const [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
      ),
    );
  }

  void _openMoreActions(HubPost post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MoreActionsSheet(
        post: post,
        onSelected: (message) {
          Navigator.of(sheetContext).pop();
          _showSnack(message);
        },
        onDelete: post.isOwn
            ? () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await _confirmDeletePost();
                if (confirmed != true) return;
                try {
                  await widget.postService.deletePost(post.id);
                } on PostServiceException catch (error) {
                  if (!mounted) return;
                  _showSnack(error.message);
                  return;
                } catch (_) {
                  if (!mounted) return;
                  _showSnack('No pudimos eliminar la publicación.');
                  return;
                }
                if (!mounted) return;
                setState(() {
                  _localPosts.removeWhere((item) => item.id == post.id);
                  _likedPosts.remove(post.id);
                  _savedPosts.remove(post.id);
                  _sharedPosts.remove(post.id);
                  _commentAdditions.remove(post.id);
                });
                _showSnack('Publicación eliminada');
              }
            : null,
        onReport: () async {
          Navigator.of(sheetContext).pop();
          await _reportPost(post);
        },
        onBlock: post.isOwn || post.authorId.isEmpty
            ? null
            : () async {
                Navigator.of(sheetContext).pop();
                await _blockPostAuthor(post);
              },
      ),
    );
  }

  Future<bool?> _confirmDeletePost() {
    return showDialog<bool>(
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
  }

  Future<void> _reportPost(HubPost post) async {
    final submitted = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      contentType: 'post',
      contentId: post.id,
      reportedUserId: post.authorId,
      title: 'Publicación de ${post.author}',
      metadata: {'author_username': post.username, 'caption': post.caption},
    );
    if (!mounted || !submitted) return;
    _showSnack('Gracias. Recibimos tu reporte y lo vamos a revisar.');
  }

  Future<void> _blockPostAuthor(HubPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text('Bloquear usuario'),
        content: Text(
          '¿Querés bloquear a ${post.author}? No podrá enviarte mensajes y vas a ver menos contenido suyo.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.safetyService.blockUser(post.authorId);
      await _restoreSafety();
      if (!mounted) return;
      _showSnack('Usuario bloqueado.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_safetyError(error));
    }
  }

  String _safetyError(Object error) {
    final message = error.toString();
    if (message.startsWith('SafetyServiceException: ')) {
      return message.replaceFirst('SafetyServiceException: ', '');
    }
    return 'No pudimos completar esta acción. Probá de nuevo.';
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

  String _countWithDelta(String value, int delta) {
    if (delta == 0) return value;
    final lower = value.toLowerCase();
    if (lower.contains('k')) return '$value+';
    final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return '${parsed + delta}';
  }

  List<HubPost> get _visibleFeedPosts {
    if (!widget.followService.usesRealProfiles) {
      return [..._localPosts, ...posts];
    }
    return _localPosts
        .where((post) => !_blockedUserIds.contains(post.authorId))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final activeReminder = widget.followService.usesRealProfiles
        ? null
        : _activeHomeReminder;
    final feedPosts = _visibleFeedPosts;
    return Stack(
      children: [
        const _NeonAtmosphere(),
        ListView(
          key: const ValueKey('home-feed-scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 18),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _StoriesRail(
                ownStories: _ownStories,
                ownAvatarAsset:
                    (widget.user ?? _fallbackPostAuthor).avatarAsset,
                followingStories: _orderedFollowingStories,
                viewedStoryIds: _viewedStoryIds,
                onCreate: _openCreateContentSheet,
                onOpenOwn: _openOwnStories,
                onOpen: _openStory,
                onSeeAll: _orderedFollowingStories.isEmpty
                    ? null
                    : () => _openStory(_orderedFollowingStories.first),
              ),
            ),
            if (activeReminder != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _HomeReminderCard(
                  reminder: activeReminder,
                  onTap: () => _openHomeFeature(
                    activeReminder.label,
                    activeReminder.title,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SuggestedProfilesRail(
                profiles: _suggestedProfiles,
                followedProfiles: _followedSuggestions,
                realMode: widget.followService.usesRealProfiles,
                onOpen: _openSuggestion,
                onFollow: _toggleSuggestionFollow,
              ),
            ),
            if (widget.followService.usesRealProfiles &&
                _followedSuggestions.isEmpty) ...[
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: _EmptyInlinePanel(
                  key: ValueKey('home-real-feed-empty'),
                  text: 'Seguí fans para ver sus publicaciones en tu inicio.',
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _HomeSectionHeader(title: 'Para ti'),
            ),
            const SizedBox(height: 8),
            ...feedPosts.map(
              (post) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _PostCard(
                    post: post,
                    liked: _likedPosts.contains(post.id),
                    saved: _savedPosts.contains(post.id),
                    shared: _sharedPosts.contains(post.id),
                    likesLabel: _countWithDelta(
                      post.likes,
                      (_likedPosts.contains(post.id) ? 1 : 0) -
                          (post.likedByCurrentUser ? 1 : 0),
                    ),
                    commentsLabel: _countWithDelta(
                      post.comments,
                      _commentAdditions[post.id] ?? 0,
                    ),
                    sharesLabel: _countWithDelta(
                      post.shares,
                      _sharedPosts.contains(post.id) ? 1 : 0,
                    ),
                    savesLabel: _countWithDelta(
                      post.saves,
                      (_savedPosts.contains(post.id) ? 1 : 0) -
                          (post.savedByCurrentUser ? 1 : 0),
                    ),
                    onLike: () => _toggleLike(post),
                    onComment: () => _openComments(post),
                    onShare: () => _openShare(post),
                    onSave: () => _toggleSave(post),
                    onOpenProfile: () => _openProfile(post),
                    onOpenTaggedPerson: _openTaggedUsername,
                    onOpenTaggedEntity: _openKpopEntity,
                    onMore: () => _openMoreActions(post),
                    videosMuted: _videosMuted,
                    onToggleVideoSound: _toggleVideoSound,
                  ),
                ),
              ),
            ),
            if (_feedLoading || _feedHasMore) const _FeedLoader(),
          ],
        ),
      ],
    );
  }
}

final _shareRecipients = demoProfiles
    .take(12)
    .map(
      (profile) => ShareRecipient(
        id: profile.id,
        name: profile.name,
        username: profile.username,
        avatarAsset: profile.avatarAsset,
      ),
    )
    .toList(growable: false);

_HomeReminder? get _activeHomeReminder {
  if (!_userHasUpcomingActivity) return null;
  return const _HomeReminder(
    label: 'Hoy 19:00',
    title: 'Random Play Dance',
    detail: 'Te anotaste al evento de Santiago. Empieza en 2 hs.',
    icon: Icons.event_available_outlined,
    color: AppTheme.cyan,
  );
}

bool get _userHasUpcomingActivity => true;

const _fallbackPostAuthor = AuthUser(
  name: 'HallyuHub',
  username: '@hallyuhub',
  email: 'local@hallyuhub.net',
  avatarAsset: '',
  fandom: '',
);

class _HomeCreateContentSheet extends StatelessWidget {
  const _HomeCreateContentSheet({required this.onStory, required this.onPost});

  final VoidCallback onStory;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 510,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: PremiumFormShell(
            title: 'Crear contenido',
            subtitle: 'Elegí cómo querés compartir este momento.',
            icon: Icons.auto_awesome_rounded,
            visual: PremiumFormVisual.create,
            child: PremiumFormSection(
              title: 'Formato',
              subtitle: 'Tus herramientas actuales siguen funcionando igual.',
              children: [
                PremiumActionTile(
                  key: const ValueKey('home-create-story'),
                  icon: Icons.auto_stories_rounded,
                  color: AppTheme.cyan,
                  title: 'Crear historia',
                  detail: 'Foto, video o texto visible durante 24 horas.',
                  onTap: onStory,
                ),
                PremiumActionTile(
                  key: const ValueKey('home-create-post'),
                  icon: Icons.add_photo_alternate_rounded,
                  color: AppTheme.rose,
                  title: 'Crear publicación',
                  detail: 'Fotos, videos, texto y etiquetas de artistas.',
                  onTap: onPost,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonAtmosphere extends StatelessWidget {
  const _NeonAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF03050B).withValues(alpha: 0.96),
                const Color(0xFF050710).withValues(alpha: 0.94),
                AppTheme.violet.withValues(alpha: 0.035),
                const Color(0xFF020309).withValues(alpha: 0.98),
              ],
              stops: const [0, 0.35, 0.7, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeReminder {
  const _HomeReminder({
    required this.label,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
}

class _HomeReminderCard extends StatelessWidget {
  const _HomeReminderCard({required this.reminder, required this.onTap});

  final _HomeReminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('home-auto-reminder'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: reminder.color.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: reminder.color.withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: reminder.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(reminder.icon, color: reminder.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.label.toUpperCase(),
                    style: TextStyle(
                      color: reminder.color,
                      fontSize: 11,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    reminder.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.54),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoriesRail extends StatelessWidget {
  const _StoriesRail({
    required this.ownStories,
    required this.ownAvatarAsset,
    required this.followingStories,
    required this.viewedStoryIds,
    required this.onCreate,
    required this.onOpenOwn,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<Story> ownStories;
  final String ownAvatarAsset;
  final List<Story> followingStories;
  final Set<String> viewedStoryIds;
  final VoidCallback onCreate;
  final VoidCallback onOpenOwn;
  final ValueChanged<Story> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Story>>{};
    for (final story in followingStories) {
      groups.putIfAbsent(story.authorId, () => []).add(story);
    }
    final storyGroups = groups.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Historias',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            if (storyGroups.isNotEmpty && onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.62),
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Ver todas',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 104,
          child: ListView.separated(
            key: const ValueKey('home-stories-carousel'),
            scrollDirection: Axis.horizontal,
            itemCount: storyGroups.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _OwnStoryCard(
                  stories: ownStories,
                  avatarAsset:
                      ownStories.firstOrNull?.avatarAsset ?? ownAvatarAsset,
                  viewed:
                      ownStories.isNotEmpty &&
                      ownStories.every(
                        (story) => viewedStoryIds.contains(story.id),
                      ),
                  onTap: ownStories.isEmpty ? onCreate : onOpenOwn,
                  onCreate: onCreate,
                );
              }
              final group = storyGroups[index - 1];
              final story = group.first;
              return _StoryCard(
                story: story,
                viewed: group.every(
                  (story) => viewedStoryIds.contains(story.id),
                ),
                onTap: () => onOpen(story),
              );
            },
          ),
        ),
        if (storyGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Seguí a otros fans para ver sus historias.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _OwnStoryCard extends StatelessWidget {
  const _OwnStoryCard({
    required this.stories,
    required this.avatarAsset,
    required this.viewed,
    required this.onTap,
    required this.onCreate,
  });

  final List<Story> stories;
  final String avatarAsset;
  final bool viewed;
  final VoidCallback onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final latestStory = stories.firstOrNull;
    return InkWell(
      key: const ValueKey('story-create'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: latestStory == null || viewed
                        ? null
                        : const SweepGradient(
                            colors: [
                              AppTheme.rose,
                              AppTheme.cyan,
                              AppTheme.amber,
                              AppTheme.violet,
                              AppTheme.rose,
                            ],
                          ),
                    border: viewed
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 2,
                          )
                        : null,
                    boxShadow: viewed
                        ? null
                        : [
                            BoxShadow(
                              color: AppTheme.rose.withValues(alpha: 0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.nightSoft,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: latestStory == null
                          ? const Icon(Icons.add, color: Colors.white, size: 28)
                          : HubAvatar(asset: avatarAsset, size: 58),
                    ),
                  ),
                ),
                if (latestStory != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: InkWell(
                      key: const ValueKey('story-create-more'),
                      onTap: onCreate,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: AppTheme.rose,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.night, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Mi historia',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              latestStory == null
                  ? 'Crear'
                  : stories.length == 1
                  ? storyRelativeTime(latestStory)
                  : '${stories.length} historias',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.viewed,
    required this.onTap,
  });

  final Story story;
  final bool viewed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('story-${story.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Container(
              key: ValueKey(
                'story-ring-${story.authorId}-${viewed ? 'viewed' : 'unviewed'}',
              ),
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: viewed
                    ? null
                    : const SweepGradient(
                        colors: [
                          AppTheme.rose,
                          AppTheme.amber,
                          AppTheme.cyan,
                          AppTheme.violet,
                          AppTheme.rose,
                        ],
                      ),
                border: viewed
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 2,
                      )
                    : null,
              ),
              child: HubAvatar(asset: story.avatarAsset, size: 62),
            ),
            const SizedBox(height: 7),
            Text(
              story.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              story.fandom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedProfilesRail extends StatelessWidget {
  const _SuggestedProfilesRail({
    required this.profiles,
    required this.followedProfiles,
    required this.realMode,
    required this.onOpen,
    required this.onFollow,
  });

  final List<CommunityProfile> profiles;
  final Set<String> followedProfiles;
  final bool realMode;
  final ValueChanged<CommunityProfile> onOpen;
  final ValueChanged<CommunityProfile> onFollow;

  @override
  Widget build(BuildContext context) {
    final visibleProfiles = profiles.isEmpty && !realMode
        ? _rankedSuggestedProfiles
        : profiles
              .where((profile) => !followedProfiles.contains(profile.id))
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeSectionHeader(title: 'Fans para descubrir'),
        const SizedBox(height: 7),
        if (visibleProfiles.isEmpty)
          const _EmptyInlinePanel(
            key: ValueKey('home-real-profiles-empty'),
            text:
                'Todavía no hay fans para sugerir. Invitá a tus amigos a HallyuHub.',
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              key: const ValueKey('home-suggested-profiles'),
              scrollDirection: Axis.horizontal,
              itemCount: visibleProfiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final profile = visibleProfiles[index];
                return _SuggestedProfileCard(
                  profile: profile,
                  reason: _suggestionReason(profile),
                  following: followedProfiles.contains(profile.id),
                  onOpen: () => onOpen(profile),
                  onFollow: () => onFollow(profile),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyInlinePanel extends StatelessWidget {
  const _EmptyInlinePanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontWeight: FontWeight.w800,
          height: 1.32,
        ),
      ),
    );
  }
}

class _SuggestedProfileCard extends StatelessWidget {
  const _SuggestedProfileCard({
    required this.profile,
    required this.reason,
    required this.following,
    required this.onOpen,
    required this.onFollow,
  });

  final CommunityProfile profile;
  final String reason;
  final bool following;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final username = profile.username.trim();
    final visibleUsername = username.isEmpty
        ? reason
        : username.startsWith('@')
        ? username
        : '@$username';

    final avatarColors = profile.colors.length >= 2
        ? profile.colors
        : const [AppTheme.rose, AppTheme.violet, AppTheme.cyan];

    return SizedBox(
      width: 208,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('home-suggestion-open-${profile.id}'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.panelRaised.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: avatarColors.first.withValues(alpha: 0.26),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        avatarColors.first,
                        AppTheme.violet,
                        avatarColors.last,
                      ],
                    ),
                  ),
                  child: HubAvatar(
                    asset: profile.avatarAsset,
                    size: 44,
                    isLive: profile.online,
                    fallbackLabel: profile.name,
                    fallbackColors: [
                      avatarColors.first.withValues(alpha: 0.88),
                      AppTheme.violet,
                      avatarColors.last.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visibleUsername,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    key: ValueKey('home-suggestion-follow-${profile.id}'),
                    onPressed: onFollow,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: following
                          ? AppTheme.cyan.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: following
                            ? AppTheme.cyan.withValues(alpha: 0.72)
                            : avatarColors.first.withValues(alpha: 0.62),
                      ),
                      minimumSize: const Size(76, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      following ? 'Siguiendo' : 'Seguir',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

List<CommunityProfile> get _rankedSuggestedProfiles {
  final profiles = [...suggestedProfiles];
  int score(CommunityProfile profile) {
    var value = 0;
    if (profile.online) value += 6;
    if (profile.city == 'Santiago') value += 4;
    if (profile.fandom == 'Stay' || profile.fandom == 'ARMY') value += 3;
    if (profile.favoriteGroup == 'Stray Kids' ||
        profile.favoriteGroup == 'BTS') {
      value += 2;
    }
    if (profile.followers.endsWith('K')) value += 1;
    return value;
  }

  profiles.sort((a, b) => score(b).compareTo(score(a)));
  return profiles;
}

String _suggestionReason(CommunityProfile profile) {
  if (profile.online) return 'Activa ahora';
  if (profile.city == 'Santiago') return 'Tu comunidad';
  if (profile.fandom == 'Stay' || profile.fandom == 'ARMY') {
    return 'Gustos parecidos';
  }
  if (profile.favoriteGroup.isNotEmpty) return profile.favoriteGroup;
  return 'Amigos de amigos';
}

// ignore: unused_element
class _SuggestedProfileSheet extends StatelessWidget {
  const _SuggestedProfileSheet({
    required this.profile,
    required this.following,
    required this.onFollow,
    required this.onMessage,
  });

  final CommunityProfile profile;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: profile.name,
      subtitle: '${profile.username} · ${profile.city}, ${profile.country}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HubAvatar(
                  asset: profile.avatarAsset,
                  size: 72,
                  isLive: profile.online,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(value: profile.followers, label: 'seguidores'),
                      _MiniStat(value: profile.posts, label: 'posts'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              profile.bio,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onFollow,
                    icon: Icon(
                      following ? Icons.check_rounded : Icons.person_add_alt_1,
                    ),
                    label: Text(following ? 'Siguiendo' : 'Seguir'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: onMessage,
                  icon: const Icon(Icons.mail_outline_rounded),
                  tooltip: 'Enviar mensaje',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureSheet extends StatelessWidget {
  const _FeatureSheet({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: title,
      subtitle: 'HallyuHub',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.liked,
    required this.saved,
    required this.shared,
    required this.likesLabel,
    required this.commentsLabel,
    required this.sharesLabel,
    required this.savesLabel,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onOpenProfile,
    required this.onOpenTaggedPerson,
    required this.onOpenTaggedEntity,
    required this.onMore,
    required this.videosMuted,
    required this.onToggleVideoSound,
  });

  final HubPost post;
  final bool liked;
  final bool saved;
  final bool shared;
  final String likesLabel;
  final String commentsLabel;
  final String sharesLabel;
  final String savesLabel;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onOpenProfile;
  final ValueChanged<String> onOpenTaggedPerson;
  final ValueChanged<KpopEntity> onOpenTaggedEntity;
  final VoidCallback onMore;
  final bool videosMuted;
  final VoidCallback onToggleVideoSound;

  @override
  Widget build(BuildContext context) {
    return HallyuPostCard(
      post: post,
      liked: liked,
      saved: saved,
      shared: shared,
      likesLabel: likesLabel,
      commentsLabel: commentsLabel,
      sharesLabel: sharesLabel,
      savesLabel: savesLabel,
      onLike: onLike,
      onComment: onComment,
      onShare: onShare,
      onSave: onSave,
      onOpenProfile: onOpenProfile,
      onOpenTaggedPerson: onOpenTaggedPerson,
      onOpenTaggedEntity: onOpenTaggedEntity,
      onMore: onMore,
      videosMuted: videosMuted,
      onToggleVideoSound: onToggleVideoSound,
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.indigo.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF130B20),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
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
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                      color: Colors.white.withValues(alpha: 0.72),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ProfilePreviewSheet extends StatelessWidget {
  const _ProfilePreviewSheet({required this.post});

  final HubPost post;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: post.author,
      subtitle: '${post.username} · ${post.mood}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HubAvatar(
                  asset: post.avatarAsset,
                  size: 72,
                  isLive: post.mood == 'En vivo',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(value: post.likes, label: 'estrellas'),
                      _MiniStat(value: post.comments, label: 'comentarios'),
                      _MiniStat(value: post.saves, label: 'guardados'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Perfil HallyuHub con actividad reciente, fandoms y acciones claras.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.tags.map(_HashtagChip.new).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Seguir'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.mail_outline_rounded),
                  tooltip: 'Enviar mensaje',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreActionsSheet extends StatelessWidget {
  const _MoreActionsSheet({
    required this.post,
    required this.onSelected,
    required this.onReport,
    this.onDelete,
    this.onBlock,
  });

  final HubPost post;
  final ValueChanged<String> onSelected;
  final VoidCallback onReport;
  final VoidCallback? onDelete;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Opciones',
      subtitle: post.author,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        children: [
          _SheetActionTile(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Seguir a ${post.author.split(' ').first}',
            subtitle: 'Ver mas publicaciones de este fandom',
            onTap: () => onSelected('Ahora sigues a ${post.author}'),
          ),
          _SheetActionTile(
            icon: Icons.visibility_off_outlined,
            title: 'Ver menos contenido similar',
            subtitle: 'Mejora el feed sin ocultar a la persona',
            onTap: () => onSelected('Tomado en cuenta para tu feed'),
          ),
          _SheetActionTile(
            icon: Icons.flag_outlined,
            title: 'Reportar',
            subtitle: 'Avisar a HallyuHub para revisión',
            onTap: onReport,
          ),
          if (onBlock != null)
            _SheetActionTile(
              icon: Icons.block_rounded,
              title: 'Bloquear usuario',
              subtitle: 'Limitar mensajes y contenido de esta persona',
              onTap: onBlock!,
            ),
          if (onDelete != null)
            _SheetActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Eliminar publicación',
              subtitle: 'Quitarla de tu perfil y del feed.',
              onTap: onDelete!,
            ),
        ],
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.rose.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.52),
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.46),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedLoader extends StatelessWidget {
  const _FeedLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LoaderDot(color: AppTheme.rose),
              _LoaderDot(color: AppTheme.cyan),
              _LoaderDot(color: AppTheme.amber),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cargando más momentos fandom...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoaderDot extends StatelessWidget {
  const _LoaderDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12),
        ],
      ),
    );
  }
}
