import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/profile_privacy_service.dart';
import '../services/share_links.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/hallyu_post_card.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/post_video_player.dart';
import '../widgets/premium_profile_visuals.dart';
import '../widgets/profile_category_chips.dart';
import '../widgets/safety_report_sheet.dart';
import '../widgets/share_sheet.dart';
import '../widgets/store_profile_card.dart';
import 'drops_screen.dart';
import 'fancams_screen.dart';
import 'kpop_entity_profile_screen.dart';
import 'messages_inbox_screen.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

enum _PublicProfileTab { posts, stories, drops, fancams }

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.profile,
    this.currentUser,
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.chatService = const LocalChatService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
  });

  final CommunityProfile profile;
  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalChatService chatService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late CommunityProfile _profile;
  bool _loading = true;
  bool _following = false;
  bool _busyFollow = false;
  bool _blockedByMe = false;
  bool _interactionBlocked = false;
  FollowCounts _counts = const FollowCounts();
  List<HubPost> _posts = const [];
  List<Story> _stories = const [];
  List<DropClip> _drops = const [];
  List<Fancam> _fancams = const [];
  List<ContentCategoryAssignment> _contentCategoryAssignments = const [];
  StoreProfile? _storeProfile;
  final Set<String> _busyPostActions = {};
  _PublicProfileTab _selectedTab = _PublicProfileTab.posts;
  ProfileContentCategory? _selectedContentCategory;

  bool get _isOwnProfile {
    return _isCurrentUserProfile(_profile);
  }

  bool get _canSeePrivateContent {
    return _canSeeContentForProfile(_profile, following: _following);
  }

  bool _isCurrentUserProfile(CommunityProfile profile) {
    final current = widget.currentUser;
    if (current == null) return false;
    return profile.username.isNotEmpty &&
        current.username.toLowerCase() == profile.username.toLowerCase();
  }

  bool _canSeeContentForProfile(
    CommunityProfile profile, {
    required bool following,
  }) {
    if (_isCurrentUserProfile(profile)) return true;
    return canViewerSeePrivateProfileContent(
      viewerId: null,
      profileOwnerId: profile.id,
      privateProfile: profile.privateProfile,
      followsProfile: following,
      viewerRole: widget.currentUser?.role ?? 'user',
    );
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    LocalFollowService.revision.addListener(_restore);
    LocalPostService.revision.addListener(_restore);
    LocalStoryService.revision.addListener(_restore);
    LocalDropService.revision.addListener(_restore);
    LocalFancamService.revision.addListener(_restore);
    LocalContentCategoryService.revision.addListener(_restore);
    LocalSafetyService.revision.addListener(_restore);
    LocalStoreProfileService.revision.addListener(_restore);
    _restore();
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.username != widget.profile.username ||
        oldWidget.profile.avatarAsset != widget.profile.avatarAsset) {
      _profile = widget.profile;
      unawaited(_restore());
    }
  }

  @override
  void dispose() {
    LocalFollowService.revision.removeListener(_restore);
    LocalPostService.revision.removeListener(_restore);
    LocalStoryService.revision.removeListener(_restore);
    LocalDropService.revision.removeListener(_restore);
    LocalFancamService.revision.removeListener(_restore);
    LocalContentCategoryService.revision.removeListener(_restore);
    LocalSafetyService.revision.removeListener(_restore);
    LocalStoreProfileService.revision.removeListener(_restore);
    super.dispose();
  }

  Future<CommunityProfile> _restoreFreshProfile() async {
    if (!widget.followService.usesRealProfiles) return _profile;
    final keys = <String>{
      _profile.id.trim(),
      _profile.username.trim(),
      _profile.username.trim().replaceFirst(RegExp(r'^@+'), ''),
      _profile.name.trim(),
    }.where((value) => value.isNotEmpty).toList(growable: false);
    for (final key in keys) {
      try {
        final matches = await widget.followService.restoreProfiles(
          query: key,
          limit: 25,
        );
        for (final candidate in matches) {
          if (_sameProfileCandidate(candidate, _profile)) {
            return _keepRealAvatar(candidate);
          }
        }
      } catch (error) {
        debugPrint(
          'PUBLIC_PROFILE_REFRESH_ERROR profileId=${_profile.id} key=$key error=$error',
        );
      }
    }
    return _profile;
  }

  CommunityProfile _keepRealAvatar(CommunityProfile freshProfile) {
    if (!_isRealProfileAvatar(_profile.avatarAsset) ||
        !_isDemoProfileAvatar(freshProfile.avatarAsset)) {
      return freshProfile;
    }
    return CommunityProfile(
      id: freshProfile.id,
      name: freshProfile.name,
      username: freshProfile.username,
      city: freshProfile.city,
      country: freshProfile.country,
      fandom: freshProfile.fandom,
      favoriteGroup: freshProfile.favoriteGroup,
      bio: freshProfile.bio,
      avatarAsset: _profile.avatarAsset,
      followers: freshProfile.followers,
      posts: freshProfile.posts,
      colors: freshProfile.colors,
      following: freshProfile.following,
      starsReceived: freshProfile.starsReceived,
      level: freshProfile.level,
      coverAsset: freshProfile.coverAsset,
      online: freshProfile.online,
      privateProfile: freshProfile.privateProfile,
      role: freshProfile.role,
    );
  }

  bool _isRealProfileAvatar(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('data:image/');
  }

  bool _isDemoProfileAvatar(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || normalized.startsWith('assets/demo-users/');
  }

  bool _sameProfileCandidate(
    CommunityProfile candidate,
    CommunityProfile target,
  ) {
    final targetId = target.id.trim();
    final targetUsername = _normalize(target.username);
    final targetName = _normalize(target.name);
    if (targetId.isNotEmpty) {
      if (candidate.id.trim() == targetId) return true;
      if (_looksLikeSupabaseId(targetId)) return false;
    }
    return (targetUsername.isNotEmpty &&
            _normalize(candidate.username) == targetUsername) ||
        (targetName.isNotEmpty && _normalize(candidate.name) == targetName);
  }

  bool _looksLikeSupabaseId(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  Future<void> _restore() async {
    final stopwatch = Stopwatch()..start();
    _logPerformance('PERF_PUBLIC_PROFILE_START profileId=${widget.profile.id}');
    try {
      final freshProfile = await _restoreFreshProfile();
      _profile = freshProfile;
      final followingIds = await widget.followService.restoreFollowingIds();
      final counts = await widget.followService.restoreCounts(freshProfile.id);
      final following = followingIds.contains(freshProfile.id);
      final blockedByMe = await widget.safetyService.hasBlockedUser(
        freshProfile.id,
      );
      final interactionBlocked = await widget.safetyService
          .isInteractionBlocked(freshProfile.id);
      final canSeePrivateContent = _canSeeContentForProfile(
        freshProfile,
        following: following,
      );
      final realProfileId = _looksLikeSupabaseId(freshProfile.id)
          ? freshProfile.id
          : null;
      final store = realProfileId == null
          ? null
          : await widget.storeProfileService.restoreStoreForOwner(
              realProfileId,
            );
      final posts = await widget.postService.restorePosts(
        authorId: widget.postService.usesRealPosts ? realProfileId : null,
        limit: 24,
      );
      final stories = canSeePrivateContent
          ? await _restoreVisibleStories(following)
          : <Story>[];
      final drops = await widget.dropService.restoreDrops(
        authorId: widget.dropService.usesRealDrops ? realProfileId : null,
        limit: 24,
      );
      final fancams = await widget.fancamService.restoreFancams(
        authorId: widget.fancamService.usesRealFancams ? realProfileId : null,
        limit: 24,
      );
      final categoryRows = canSeePrivateContent
          ? await widget.contentCategoryService.restoreForUser(freshProfile.id)
          : <ContentCategoryAssignment>[];
      if (!mounted) return;
      final visiblePosts = interactionBlocked || !canSeePrivateContent
          ? <HubPost>[]
          : posts
                .where(_isProfilePost)
                .where((post) => _canViewPost(post, following))
                .toList(growable: false);
      final visibleDrops = interactionBlocked || !canSeePrivateContent
          ? <DropClip>[]
          : drops.where(_isProfileDrop).toList(growable: false);
      final visibleFancams = interactionBlocked || !canSeePrivateContent
          ? <Fancam>[]
          : fancams.where(_isProfileFancam).toList(growable: false);
      setState(() {
        _profile = freshProfile;
        _following = following;
        _blockedByMe = blockedByMe;
        _interactionBlocked = interactionBlocked;
        _counts = counts;
        _posts = visiblePosts;
        _stories = stories;
        _drops = visibleDrops;
        _fancams = visibleFancams;
        _contentCategoryAssignments = categoryRows;
        _storeProfile =
            store != null &&
                (_isOwnProfile || store.status == StoreProfileStatus.active)
            ? store
            : null;
        if (_loading || _tabItems(_selectedTab).isEmpty) {
          _selectedTab = _firstAvailableTab(
            posts: visiblePosts,
            stories: stories,
            drops: visibleDrops,
            fancams: visibleFancams,
          );
        }
        _loading = false;
      });
      _logPerformance(
        'PERF_PUBLIC_PROFILE_OK posts=${visiblePosts.length} drops=${visibleDrops.length} fancams=${visibleFancams.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    } catch (error) {
      debugPrint(
        'PROFILE_OPEN_ERROR publicProfile profileId=${_profile.id} error=$error',
      );
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Story>> _restoreVisibleStories(bool following) async {
    if (!_canSeeContentForProfile(_profile, following: following)) {
      return const [];
    }
    if (_isOwnProfile) return widget.storyService.restoreOwnStories();
    if (!following) return const [];
    final stories = await widget.storyService.restoreFollowingStories(
      followingIds: {_profile.id},
    );
    return stories.where(_isProfileStory).toList(growable: false);
  }

  bool _isProfilePost(HubPost post) {
    return _sameAuthor(
      id: post.authorId,
      username: post.username,
      name: post.author,
    );
  }

  bool _canViewPost(HubPost post, bool following) {
    if (!_canSeeContentForProfile(_profile, following: following)) {
      return false;
    }
    if (_isOwnProfile || following) return true;
    final privacy = post.privacy.toLowerCase().trim();
    return privacy.isEmpty ||
        privacy == 'todos' ||
        privacy == 'publico' ||
        privacy == 'público' ||
        privacy == 'public';
  }

  bool _isProfileStory(Story story) {
    return _sameAuthor(id: story.authorId, username: '', name: story.name);
  }

  bool _isProfileDrop(DropClip drop) {
    return _sameAuthor(
      id: drop.creatorId,
      username: drop.creator,
      name: drop.creatorName,
    );
  }

  bool _isProfileFancam(Fancam fancam) {
    return _sameAuthor(
      id: fancam.creatorId,
      username: fancam.creator,
      name: fancam.creatorName,
    );
  }

  bool _sameAuthor({
    required String id,
    required String username,
    required String name,
  }) {
    final profileId = _profile.id.trim();
    final profileUsername = _normalize(_profile.username);
    final profileName = _normalize(_profile.name);
    return (profileId.isNotEmpty && id.trim() == profileId) ||
        (profileUsername.isNotEmpty &&
            _normalize(username) == profileUsername) ||
        (profileName.isNotEmpty && _normalize(name) == profileName);
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');

  _PublicProfileTab _firstAvailableTab({
    required List<HubPost> posts,
    required List<Story> stories,
    required List<DropClip> drops,
    required List<Fancam> fancams,
  }) {
    if (posts.isNotEmpty) return _PublicProfileTab.posts;
    if (stories.isNotEmpty) return _PublicProfileTab.stories;
    if (drops.isNotEmpty) return _PublicProfileTab.drops;
    if (fancams.isNotEmpty) return _PublicProfileTab.fancams;
    return _PublicProfileTab.posts;
  }

  List<Object> _tabItems(_PublicProfileTab tab) {
    return switch (tab) {
      _PublicProfileTab.posts => _posts,
      _PublicProfileTab.stories => _stories,
      _PublicProfileTab.drops => _drops,
      _PublicProfileTab.fancams => _fancams,
    };
  }

  Map<ProfileContentCategory, int> get _categoryCounts {
    return {
      for (final category in ProfileContentCategory.values)
        category:
            _categoryPosts(category).length +
            _categoryDrops(category).length +
            _categoryFancams(category).length,
    };
  }

  bool _hasCategory({
    required ProfileContentCategory category,
    required ProfileContentType contentType,
    required String contentId,
  }) {
    return _contentCategoryAssignments.any(
      (row) =>
          row.category == category &&
          row.contentType == contentType &&
          row.contentId == contentId,
    );
  }

  List<HubPost> _categoryPosts(ProfileContentCategory category) {
    return _posts
        .where(
          (post) => _hasCategory(
            category: category,
            contentType: ProfileContentType.post,
            contentId: post.id,
          ),
        )
        .toList(growable: false);
  }

  List<DropClip> _categoryDrops(ProfileContentCategory category) {
    return _drops
        .where(
          (drop) => _hasCategory(
            category: category,
            contentType: ProfileContentType.drop,
            contentId: _dropId(drop),
          ),
        )
        .toList(growable: false);
  }

  List<Fancam> _categoryFancams(ProfileContentCategory category) {
    return _fancams
        .where(
          (fancam) => _hasCategory(
            category: category,
            contentType: ProfileContentType.fancam,
            contentId: _fancamKey(fancam),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _toggleFollow() async {
    if (_busyFollow || _isOwnProfile) return;
    final previous = _following;
    setState(() {
      _busyFollow = true;
      _following = !_following;
    });
    try {
      final nowFollowing = await widget.followService.toggleFollowing(
        _profile.id,
      );
      if (!mounted) return;
      setState(() => _following = nowFollowing);
      await _restore();
      if (!mounted) return;
      _showSnack(nowFollowing ? 'Siguiendo' : 'Dejaste de seguir');
    } catch (error) {
      debugPrint(
        'PROFILE_OPEN_ERROR follow profileId=${_profile.id} error=$error',
      );
      if (!mounted) return;
      setState(() => _following = previous);
      _showSnack('No pudimos actualizar el seguimiento.');
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Future<void> _togglePostStar(HubPost post) async {
    if (!_canSeePrivateContent) {
      _showSnack('Este perfil es privado. Seguí a este usuario para ver más.');
      return;
    }
    if (_busyPostActions.contains('star-${post.id}')) return;
    final nextLiked = !post.likedByCurrentUser;
    setState(() => _busyPostActions.add('star-${post.id}'));
    try {
      await widget.postService.setPostLiked(post.id, nextLiked);
      await _restore();
      if (!mounted) return;
      _showSnack(nextLiked ? 'Estrella agregada' : 'Estrella quitada');
    } catch (error) {
      debugPrint(
        'PUBLIC_PROFILE_POST_STAR_ERROR postId=${post.id} error=$error',
      );
      if (!mounted) return;
      _showSnack('No pudimos actualizar la estrella.');
    } finally {
      if (mounted) setState(() => _busyPostActions.remove('star-${post.id}'));
    }
  }

  Future<void> _togglePostSave(HubPost post) async {
    if (!_canSeePrivateContent) {
      _showSnack('Este perfil es privado. Seguí a este usuario para ver más.');
      return;
    }
    if (_busyPostActions.contains('save-${post.id}')) return;
    final nextSaved = !post.savedByCurrentUser;
    setState(() => _busyPostActions.add('save-${post.id}'));
    try {
      await widget.postService.setPostSaved(post.id, nextSaved);
      await _restore();
      if (!mounted) return;
      _showSnack(nextSaved ? 'Post guardado' : 'Guardado quitado');
    } catch (error) {
      debugPrint(
        'PUBLIC_PROFILE_POST_SAVE_ERROR postId=${post.id} error=$error',
      );
      if (!mounted) return;
      _showSnack('No pudimos actualizar el guardado.');
    } finally {
      if (mounted) setState(() => _busyPostActions.remove('save-${post.id}'));
    }
  }

  void _sharePost(HubPost post) {
    if (!_canSeePrivateContent) {
      _showSnack('Este perfil es privado. Seguí a este usuario para ver más.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => AppShareSheet(
        title: 'Compartir publicación',
        subtitle: post.caption.isEmpty ? 'Publicación' : post.caption,
        shareText: '${post.caption}\n${ShareLinks.publication(post.id)}',
        recipients: const [],
        onSelected: (label) {
          Navigator.of(sheetContext).pop();
          _showSnack(label);
        },
      ),
    );
  }

  void _openPostActions(HubPost post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PublicPostActionTile(
                icon: Icons.mode_comment_outlined,
                title: 'Ver comentarios',
                subtitle: 'Abrir conversación de la publicación.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openPostComments(post);
                },
              ),
              _PublicPostActionTile(
                icon: Icons.share_outlined,
                title: 'Compartir',
                subtitle: 'Enviar esta publicación.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _sharePost(post);
                },
              ),
              if (_isOwnProfile || post.isOwn)
                _PublicPostActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Eliminar publicación',
                  subtitle: 'Quitarla de tu perfil y del feed.',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteOwnPost(post);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteOwnPost(HubPost post) async {
    if (!_isOwnProfile && !post.isOwn) return;
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
    if (confirmed != true) return;
    try {
      await widget.postService.deletePost(post.id);
      if (!mounted) return;
      setState(() {
        _posts = _posts.where((item) => item.id != post.id).toList();
        _contentCategoryAssignments = _contentCategoryAssignments
            .where(
              (item) =>
                  item.contentType != ProfileContentType.post ||
                  item.contentId != post.id,
            )
            .toList(growable: false);
      });
      _showSnack('Publicación eliminada');
    } on PostServiceException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (error) {
      debugPrint('PUBLIC_PROFILE_DELETE_POST_ERROR id=${post.id} error=$error');
      if (!mounted) return;
      _showSnack('No pudimos eliminar la publicación. Probá de nuevo.');
    }
  }

  Future<void> _openPostComments(HubPost post) async {
    if (!_canSeePrivateContent) {
      _showSnack('Este perfil es privado. Seguí a este usuario para comentar.');
      return;
    }
    List<PostComment> initialComments;
    try {
      initialComments = await widget.postService.restoreComments(post.id);
    } on PostServiceException catch (error) {
      if (error.message.contains('no está disponible')) {
        if (mounted) {
          setState(() {
            _posts = _posts.where((item) => item.id != post.id).toList();
          });
          _showSnack(error.message);
        }
        return;
      }
      debugPrint(
        'PUBLIC_PROFILE_COMMENTS_ERROR postId=${post.id} error=$error',
      );
      initialComments = const [];
      if (mounted) _showSnack(error.message);
    } catch (error) {
      debugPrint(
        'PUBLIC_PROFILE_COMMENTS_ERROR postId=${post.id} error=$error',
      );
      initialComments = const [];
      if (mounted) _showSnack('No pudimos cargar comentarios reales.');
    }
    if (!mounted) return;
    final commenter =
        widget.currentUser ??
        AuthUser(
          name: 'Fan Hallyu',
          username: '@fan',
          email: '',
          avatarAsset: _profile.avatarAsset,
          fandom: 'HallyuHub',
        );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        threadId: post.id,
        subtitle: post.caption.isEmpty ? 'Publicación' : post.caption,
        initialComments: initialComments,
        currentUserName: commenter.name,
        currentUsername: commenter.username,
        currentUserAvatar: commenter.avatarAsset,
        safetyService: widget.safetyService,
        reportContentType: 'comment',
        onSubmitComment: (body, parentId) => widget.postService.addComment(
          author: commenter,
          postId: post.id,
          body: body,
          parentId: parentId,
        ),
        onDeleteComment: (comment) => widget.postService.deleteComment(
          postId: post.id,
          commentId: comment.id,
        ),
        onChanged: (_) {},
        onCommentAdded: () => _restore(),
        onCommentsRemoved: (_) => _restore(),
      ),
    );
  }

  void _openMessage() {
    if (_interactionBlocked) {
      _showSnack('No podés enviar mensajes a este usuario.');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DirectChatScreen(
          profile: _profile,
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

  void _openDrop(DropClip drop) {
    if (!_canSeePrivateContent) {
      _showSnack(
        'Este perfil es privado. Seguí a este usuario para ver Drops.',
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DropsScreen(
          user: widget.currentUser,
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
  }

  void _openKpopEntity(KpopEntity entity) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => KpopEntityProfileScreen(
          entity: entity,
          currentUser: widget.currentUser,
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

  void _openFancam(Fancam fancam) {
    if (!_canSeePrivateContent) {
      _showSnack(
        'Este perfil es privado. Seguí a este usuario para ver Fancams.',
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FancamsScreen(
          user: widget.currentUser,
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
  }

  String _dropId(DropClip drop) {
    if (drop.id.isNotEmpty) return drop.id;
    return drop.title.toLowerCase().replaceAll(' ', '-');
  }

  String _fancamKey(Fancam fancam) {
    if (fancam.id.isNotEmpty) return fancam.id;
    return '${fancam.creatorId}-${fancam.artistId}-${fancam.title}';
  }

  Future<void> _openConnections({required bool followers}) async {
    final title = followers ? 'Seguidores' : 'Siguiendo';
    List<CommunityProfile> profiles;
    try {
      profiles = followers
          ? await widget.followService.restoreFollowers(_profile.id)
          : await widget.followService.restoreFollowingProfiles(_profile.id);
    } catch (error) {
      debugPrint(
        'FOLLOW_LIST_ERROR publicProfile profileId=${_profile.id} type=$title error=$error',
      );
      profiles = const [];
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConnectionsSheet(
        title: title,
        profiles: profiles,
        onOpen: (profile) {
          Navigator.of(context).pop();
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => PublicProfileScreen(
                profile: profile,
                currentUser: widget.currentUser,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reportProfile() async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      title: 'Reportar perfil: ${_profile.name}',
      contentType: 'profile',
      reportedUserId: _profile.id,
      metadata: {'username': _profile.username, 'profile_name': _profile.name},
    );
    if (!mounted || !sent) return;
    _showSnack('Gracias. Recibimos tu reporte y lo vamos a revisar.');
  }

  Future<void> _toggleBlock() async {
    if (_isOwnProfile) return;
    if (_blockedByMe) {
      try {
        await widget.safetyService.unblockUser(_profile.id);
        await _restore();
        if (!mounted) return;
        _showSnack('Usuario desbloqueado.');
      } catch (error) {
        if (!mounted) return;
        _showSnack(_safetyError(error));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Bloquear usuario',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Si bloqueás a ${_profile.name}, no podrán enviarse mensajes y vas a ver menos contenido suyo.',
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
      await widget.safetyService.blockUser(_profile.id);
      await _restore();
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _profile.colors.isEmpty
        ? const [AppTheme.rose, AppTheme.cyan, AppTheme.violet]
        : _profile.colors.take(3).toList(growable: false);
    final selectedCategory = _selectedContentCategory;
    final canSeePrivateContent = _canSeePrivateContent;
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: Text(
          _profile.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (!_isOwnProfile)
            PopupMenuButton<String>(
              tooltip: 'Seguridad',
              color: AppTheme.nightSoft,
              iconColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              onSelected: (value) {
                if (value == 'report') {
                  unawaited(_reportProfile());
                } else if (value == 'block') {
                  unawaited(_toggleBlock());
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'report',
                  child: _SafetyMenuLabel(
                    icon: Icons.flag_outlined,
                    label: 'Reportar perfil',
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: _SafetyMenuLabel(
                    icon: _blockedByMe
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                    label: _blockedByMe
                        ? 'Desbloquear usuario'
                        : 'Bloquear usuario',
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _restore,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _PublicProfileHero(
              profile: _profile,
              colors: colors,
              followers: _counts.followers,
              following: _counts.following,
              posts: _posts.length,
              followingUser: _following,
              busyFollow: _busyFollow || _interactionBlocked,
              isOwnProfile: _isOwnProfile,
              onFollow: _toggleFollow,
              onMessage: _openMessage,
              onFollowers: () => _openConnections(followers: true),
              onFollowing: () => _openConnections(followers: false),
            ),
            if (_storeProfile != null) ...[
              const SizedBox(height: 16),
              StoreProfileCard(
                store: _storeProfile!,
                avatarAsset: _profile.avatarAsset,
                followersLabel: _formatCompactCount(_counts.followers),
                postsLabel: _posts.length.toString(),
                savesLabel: '0',
                isOwnProfile: _isOwnProfile,
                following: _following,
                busyFollow: _busyFollow || _interactionBlocked,
                onFollow: _isOwnProfile ? null : _toggleFollow,
                onMessage: _isOwnProfile ? null : _openMessage,
                onReport: _isOwnProfile ? null : _reportProfile,
              ),
            ],
            const SizedBox(height: 16),
            if (_blockedByMe) ...[
              _BlockedProfileNotice(onUnblock: _toggleBlock),
              const SizedBox(height: 12),
            ] else if (_interactionBlocked) ...[
              const _EmptyProfilePanel(
                text: 'No podés interactuar con este perfil.',
              ),
              const SizedBox(height: 12),
            ] else if (_loading)
              const _PublicProfileLoading()
            else if (!canSeePrivateContent) ...[
              _PrivateProfileNotice(
                busyFollow: _busyFollow,
                onFollow: _toggleFollow,
              ),
            ] else ...[
              PremiumProfileFeatureDeck(
                title: 'Contenido',
                items: [
                  ProfileFeatureItem(
                    id: 'public-posts-${_profile.id}',
                    title: 'Posts',
                    value: _posts.length.toString(),
                    detail: 'publicaciones',
                    icon: Icons.edit_note_rounded,
                    colors: const [AppTheme.rose, AppTheme.violet],
                    onTap: () => setState(() {
                      _selectedContentCategory = null;
                      _selectedTab = _PublicProfileTab.posts;
                    }),
                  ),
                  ProfileFeatureItem(
                    id: 'public-stories-${_profile.id}',
                    title: 'Stories',
                    value: _stories.length.toString(),
                    detail: 'activas',
                    icon: Icons.auto_stories_rounded,
                    colors: const [AppTheme.amber, AppTheme.rose],
                    onTap: () => setState(() {
                      _selectedContentCategory = null;
                      _selectedTab = _PublicProfileTab.stories;
                    }),
                  ),
                  ProfileFeatureItem(
                    id: 'public-drops-${_profile.id}',
                    title: 'Drops',
                    value: _drops.length.toString(),
                    detail: 'momentos',
                    icon: Icons.play_circle_fill_rounded,
                    colors: const [AppTheme.cyan, AppTheme.violet],
                    onTap: () => setState(() {
                      _selectedContentCategory = null;
                      _selectedTab = _PublicProfileTab.drops;
                    }),
                  ),
                  ProfileFeatureItem(
                    id: 'public-fancams-${_profile.id}',
                    title: 'Fancams',
                    value: _fancams.length.toString(),
                    detail: 'videos',
                    icon: Icons.videocam_rounded,
                    colors: const [AppTheme.violet, AppTheme.cyan],
                    onTap: () => setState(() {
                      _selectedContentCategory = null;
                      _selectedTab = _PublicProfileTab.fancams;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ProfileCategoryRail(
                counts: _categoryCounts,
                selected: selectedCategory,
                onSelected: (category) {
                  setState(() => _selectedContentCategory = category);
                },
              ),
              const SizedBox(height: 12),
              if (selectedCategory == null) ...[
                const ProfileVisualSectionHeader(
                  title: 'Actividad',
                  icon: Icons.grid_view_rounded,
                ),
                const SizedBox(height: 10),
                _PublicProfileTabs(
                  selected: _selectedTab,
                  counts: {
                    _PublicProfileTab.posts: _posts.length,
                    _PublicProfileTab.stories: _stories.length,
                    _PublicProfileTab.drops: _drops.length,
                    _PublicProfileTab.fancams: _fancams.length,
                  },
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                ),
                const SizedBox(height: 12),
              ],
              if (selectedCategory != null)
                _PublicProfileCategoryBody(
                  category: selectedCategory,
                  posts: _categoryPosts(selectedCategory),
                  drops: _categoryDrops(selectedCategory),
                  fancams: _categoryFancams(selectedCategory),
                  onStarPost: _togglePostStar,
                  onCommentPost: _openPostComments,
                  onSharePost: _sharePost,
                  onSavePost: _togglePostSave,
                  onMorePost: _openPostActions,
                  onOpenDrop: _openDrop,
                  onOpenFancam: _openFancam,
                  onOpenTaggedEntity: _openKpopEntity,
                )
              else
                _PublicProfileTabBody(
                  tab: _selectedTab,
                  posts: _posts,
                  stories: _stories,
                  drops: _drops,
                  fancams: _fancams,
                  following: _following,
                  isOwnProfile: _isOwnProfile,
                  usesRealContent:
                      widget.postService.usesRealPosts ||
                      widget.storyService.usesRealStories ||
                      widget.dropService.usesRealDrops ||
                      widget.fancamService.usesRealFancams,
                  onStarPost: _togglePostStar,
                  onCommentPost: _openPostComments,
                  onSharePost: _sharePost,
                  onSavePost: _togglePostSave,
                  onMorePost: _openPostActions,
                  onOpenDrop: _openDrop,
                  onOpenFancam: _openFancam,
                  onOpenTaggedEntity: _openKpopEntity,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicProfileHero extends StatelessWidget {
  const _PublicProfileHero({
    required this.profile,
    required this.colors,
    required this.followers,
    required this.following,
    required this.posts,
    required this.followingUser,
    required this.busyFollow,
    required this.isOwnProfile,
    required this.onFollow,
    required this.onMessage,
    required this.onFollowers,
    required this.onFollowing,
  });

  final CommunityProfile profile;
  final List<Color> colors;
  final int followers;
  final int following;
  final int posts;
  final bool followingUser;
  final bool busyFollow;
  final bool isOwnProfile;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('public-profile-full'),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF101421),
            colors.first.withValues(alpha: 0.12),
            const Color(0xFF070A12),
            colors.last.withValues(alpha: 0.08),
          ],
          stops: const [0, 0.34, 0.72, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.rose, AppTheme.violet, AppTheme.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.violet.withValues(alpha: 0.2),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: HubAvatar(
                  asset: profile.avatarAsset,
                  size: 112,
                  isLive: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.06,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.username} · ${_publicLocationLabel(profile)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.cyan.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Fandoms',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 7,
            runSpacing: 7,
            children: [
              if (profile.fandom.trim().isNotEmpty)
                _ProfilePill(profile.fandom),
              if (profile.favoriteGroup.trim().isNotEmpty)
                _ProfilePill(profile.favoriteGroup),
              _ProfilePill('Nivel ${profile.level}'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatButton(
                  key: ValueKey('public-profile-${profile.id}-stat-posts'),
                  value: '$posts',
                  label: 'posts',
                  onTap: () {},
                ),
              ),
              Expanded(
                child: _StatButton(
                  key: ValueKey('public-profile-${profile.id}-stat-seguidores'),
                  value: '$followers',
                  label: 'seguidores',
                  onTap: onFollowers,
                ),
              ),
              Expanded(
                child: _StatButton(
                  key: ValueKey('public-profile-${profile.id}-stat-siguiendo'),
                  value: '$following',
                  label: 'siguiendo',
                  onTap: onFollowing,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isOwnProfile)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busyFollow ? null : onFollow,
                    icon: Icon(
                      followingUser
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                    ),
                    label: Text(followingUser ? 'Siguiendo' : 'Seguir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Mensaje'),
                  ),
                ),
              ],
            )
          else
            const _OwnProfileNotice(),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({
    super.key,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
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

class _ProfilePill extends StatelessWidget {
  const _ProfilePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.24)),
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

class _OwnProfileNotice extends StatelessWidget {
  const _OwnProfileNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Este es tu perfil visto como público.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyProfilePanel extends StatelessWidget {
  const _EmptyProfilePanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BlockedProfileNotice extends StatelessWidget {
  const _BlockedProfileNotice({required this.onUnblock});

  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppTheme.rose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Usuario bloqueado. Podés desbloquearlo cuando quieras.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(onPressed: onUnblock, child: const Text('Desbloquear')),
        ],
      ),
    );
  }
}

class _PrivateProfileNotice extends StatelessWidget {
  const _PrivateProfileNotice({
    required this.busyFollow,
    required this.onFollow,
  });

  final bool busyFollow;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.nightSoft.withValues(alpha: 0.96),
            AppTheme.violet.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.rose, AppTheme.cyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.rose.withValues(alpha: 0.24),
                  blurRadius: 22,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Este perfil es privado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seguí a este usuario para ver sus publicaciones, Drops, Fancams, stories y actividad.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busyFollow ? null : onFollow,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Seguir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyMenuLabel extends StatelessWidget {
  const _SafetyMenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.cyan, size: 19),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

String _formatCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

class _PublicProfileTabs extends StatelessWidget {
  const _PublicProfileTabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _PublicProfileTab selected;
  final Map<_PublicProfileTab, int> counts;
  final ValueChanged<_PublicProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _PublicProfileTab.values) ...[
            _PublicProfileTabChip(
              tab: tab,
              count: counts[tab] ?? 0,
              selected: selected == tab,
              onTap: () => onChanged(tab),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PublicProfileTabChip extends StatelessWidget {
  const _PublicProfileTabChip({
    required this.tab,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _PublicProfileTab tab;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppTheme.violet.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppTheme.violet.withValues(alpha: 0.46)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          '${_tabLabel(tab)} · $count',
          style: TextStyle(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _tabLabel(_PublicProfileTab tab) {
    return switch (tab) {
      _PublicProfileTab.posts => 'Publicaciones',
      _PublicProfileTab.stories => 'Stories',
      _PublicProfileTab.drops => 'Drops',
      _PublicProfileTab.fancams => 'Fancams',
    };
  }
}

class _PublicProfileLoading extends StatelessWidget {
  const _PublicProfileLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppTheme.cyan,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cargando actividad del perfil...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfileTabBody extends StatelessWidget {
  const _PublicProfileTabBody({
    required this.tab,
    required this.posts,
    required this.stories,
    required this.drops,
    required this.fancams,
    required this.following,
    required this.isOwnProfile,
    required this.usesRealContent,
    required this.onStarPost,
    required this.onCommentPost,
    required this.onSharePost,
    required this.onSavePost,
    required this.onMorePost,
    required this.onOpenDrop,
    required this.onOpenFancam,
    required this.onOpenTaggedEntity,
  });

  final _PublicProfileTab tab;
  final List<HubPost> posts;
  final List<Story> stories;
  final List<DropClip> drops;
  final List<Fancam> fancams;
  final bool following;
  final bool isOwnProfile;
  final bool usesRealContent;
  final ValueChanged<HubPost> onStarPost;
  final ValueChanged<HubPost> onCommentPost;
  final ValueChanged<HubPost> onSharePost;
  final ValueChanged<HubPost> onSavePost;
  final ValueChanged<HubPost> onMorePost;
  final ValueChanged<DropClip> onOpenDrop;
  final ValueChanged<Fancam> onOpenFancam;
  final ValueChanged<KpopEntity> onOpenTaggedEntity;

  @override
  Widget build(BuildContext context) {
    final emptyText = _emptyText;
    return switch (tab) {
      _PublicProfileTab.posts =>
        posts.isEmpty
            ? _EmptyProfilePanel(text: emptyText)
            : Column(
                children: [
                  for (final post in posts) ...[
                    _PublicPostCard(
                      post: post,
                      onStar: () => onStarPost(post),
                      onComment: () => onCommentPost(post),
                      onShare: () => onSharePost(post),
                      onSave: () => onSavePost(post),
                      onMore: () => onMorePost(post),
                      onOpenTaggedEntity: onOpenTaggedEntity,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      _PublicProfileTab.stories =>
        stories.isEmpty
            ? _EmptyProfilePanel(text: emptyText)
            : Column(
                children: [
                  for (final story in stories) ...[
                    _StoryActivityCard(story: story),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      _PublicProfileTab.drops =>
        drops.isEmpty
            ? _EmptyProfilePanel(text: emptyText)
            : Column(
                children: [
                  for (final drop in drops) ...[
                    _DropActivityCard(
                      drop: drop,
                      onOpen: () => onOpenDrop(drop),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      _PublicProfileTab.fancams =>
        fancams.isEmpty
            ? _EmptyProfilePanel(text: emptyText)
            : Column(
                children: [
                  for (final fancam in fancams) ...[
                    _FancamActivityCard(
                      fancam: fancam,
                      onOpen: () => onOpenFancam(fancam),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
    };
  }

  String get _emptyText {
    if (!isOwnProfile && !following && usesRealContent) {
      return 'Todavía no hay contenido público visible. Si este perfil es limitado, seguí a esta fan para ver más actividad.';
    }
    return switch (tab) {
      _PublicProfileTab.posts =>
        'Este perfil todavía no tiene publicaciones visibles.',
      _PublicProfileTab.stories =>
        'No hay stories activas visibles en este momento.',
      _PublicProfileTab.drops => 'Este perfil todavía no tiene Drops visibles.',
      _PublicProfileTab.fancams =>
        'Este perfil todavía no tiene Fancams visibles.',
    };
  }
}

class _PublicProfileCategoryBody extends StatelessWidget {
  const _PublicProfileCategoryBody({
    required this.category,
    required this.posts,
    required this.drops,
    required this.fancams,
    required this.onStarPost,
    required this.onCommentPost,
    required this.onSharePost,
    required this.onSavePost,
    required this.onMorePost,
    required this.onOpenDrop,
    required this.onOpenFancam,
    required this.onOpenTaggedEntity,
  });

  final ProfileContentCategory category;
  final List<HubPost> posts;
  final List<DropClip> drops;
  final List<Fancam> fancams;
  final ValueChanged<HubPost> onStarPost;
  final ValueChanged<HubPost> onCommentPost;
  final ValueChanged<HubPost> onSharePost;
  final ValueChanged<HubPost> onSavePost;
  final ValueChanged<HubPost> onMorePost;
  final ValueChanged<DropClip> onOpenDrop;
  final ValueChanged<Fancam> onOpenFancam;
  final ValueChanged<KpopEntity> onOpenTaggedEntity;

  @override
  Widget build(BuildContext context) {
    final hasContent =
        posts.isNotEmpty || drops.isNotEmpty || fancams.isNotEmpty;
    if (!hasContent) {
      return _EmptyProfilePanel(
        text:
            'Todavía no hay contenido en ${category.label}. Cuando esta fan guarde algo en esta sección, lo vas a ver acá.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final post in posts) ...[
          _PublicPostCard(
            post: post,
            onStar: () => onStarPost(post),
            onComment: () => onCommentPost(post),
            onShare: () => onSharePost(post),
            onSave: () => onSavePost(post),
            onMore: () => onMorePost(post),
            onOpenTaggedEntity: onOpenTaggedEntity,
          ),
          const SizedBox(height: 12),
        ],
        for (final drop in drops) ...[
          _DropActivityCard(drop: drop, onOpen: () => onOpenDrop(drop)),
          const SizedBox(height: 10),
        ],
        for (final fancam in fancams) ...[
          _FancamActivityCard(
            fancam: fancam,
            onOpen: () => onOpenFancam(fancam),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StoryActivityCard extends StatelessWidget {
  const _StoryActivityCard({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    return _MediaActivityCard(
      icon: Icons.auto_stories_rounded,
      label: 'Story activa',
      title: story.title.isEmpty ? story.text : story.title,
      subtitle: story.detail.isEmpty ? story.timeLabel : story.detail,
      meta: '${story.views} vistas · ${story.stars} estrellas',
      imageAsset: story.imageAsset,
      mediaPath: story.mediaPath,
      isVideo: story.contentType == StoryContentType.video,
    );
  }
}

class _DropActivityCard extends StatelessWidget {
  const _DropActivityCard({required this.drop, required this.onOpen});

  final DropClip drop;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _MediaActivityCard(
      icon: Icons.bolt_rounded,
      label: 'Drop',
      title: drop.caption.isEmpty ? drop.title : drop.caption,
      subtitle: drop.artist,
      meta: '${drop.likes} estrellas · ${drop.comments} comentarios',
      imageAsset: drop.imageAsset,
      mediaPath: drop.videoPath,
      isVideo: drop.hasVideo,
      onTap: onOpen,
      actionLabel: 'Ver Drop',
    );
  }
}

class _FancamActivityCard extends StatelessWidget {
  const _FancamActivityCard({required this.fancam, required this.onOpen});

  final Fancam fancam;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _MediaActivityCard(
      icon: Icons.play_circle_fill_rounded,
      label: 'Fancam',
      title: fancam.caption.isEmpty ? fancam.title : fancam.caption,
      subtitle: fancam.artist,
      meta:
          '${fancam.likes} estrellas · ${fancam.comments} comentarios · ${fancam.duration}',
      imageAsset: fancam.imageAsset,
      mediaPath: fancam.videoPath,
      isVideo: fancam.hasVideo,
      onTap: onOpen,
      actionLabel: 'Ver Fancam',
    );
  }
}

class _MediaActivityCard extends StatelessWidget {
  const _MediaActivityCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.imageAsset,
    required this.mediaPath,
    required this.isVideo,
    this.onTap,
    this.actionLabel = '',
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final String meta;
  final String imageAsset;
  final String mediaPath;
  final bool isVideo;
  final VoidCallback? onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 126,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (mediaPath.isNotEmpty && isVideo)
                  PostVideoPlayer(path: mediaPath, muted: true)
                else if (imageAsset.startsWith('http'))
                  Image.network(imageAsset, fit: BoxFit.cover)
                else if (imageAsset.isNotEmpty)
                  Image.asset(imageAsset, fit: BoxFit.cover)
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.rose, AppTheme.cyan],
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    isVideo ? Icons.play_arrow_rounded : icon,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityBadge(icon: icon, label: label),
                  const SizedBox(height: 10),
                  Text(
                    title.isEmpty ? label : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (actionLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppTheme.cyan,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          actionLabel,
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.cyan.withValues(alpha: 0.16),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionsSheet extends StatefulWidget {
  const _ConnectionsSheet({
    required this.title,
    required this.profiles,
    required this.onOpen,
  });

  final String title;
  final List<CommunityProfile> profiles;
  final ValueChanged<CommunityProfile> onOpen;

  @override
  State<_ConnectionsSheet> createState() => _ConnectionsSheetState();
}

class _ConnectionsSheetState extends State<_ConnectionsSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CommunityProfile> get _filteredProfiles {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.profiles;
    return widget.profiles
        .where((profile) {
          final initials = profile.name
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map((part) => part.substring(0, 1).toLowerCase())
              .join();
          return profile.name.toLowerCase().contains(query) ||
              initials.contains(query) ||
              profile.username.toLowerCase().contains(query) ||
              profile.fandom.toLowerCase().contains(query) ||
              profile.favoriteGroup.toLowerCase().contains(query) ||
              profile.city.toLowerCase().contains(query) ||
              profile.country.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _filteredProfiles;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('connections-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, usuario o fandom',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppTheme.cyan),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (profiles.isEmpty)
              const _EmptyProfilePanel(
                text: 'Todavía no hay perfiles visibles.',
              )
            else
              for (final profile in profiles) ...[
                _ConnectionTile(
                  key: ValueKey('connection-${profile.id}'),
                  profile: profile,
                  onTap: () => widget.onOpen(profile),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    super.key,
    required this.profile,
    required this.onTap,
  });

  final CommunityProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              HubAvatar(asset: profile.avatarAsset, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${profile.username} · ${profile.fandom}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicPostCard extends StatelessWidget {
  const _PublicPostCard({
    required this.post,
    required this.onStar,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onOpenTaggedEntity,
    this.onMore,
  });

  final HubPost post;
  final VoidCallback onStar;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final ValueChanged<KpopEntity> onOpenTaggedEntity;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return HallyuPostCard(
      post: post,
      liked: post.likedByCurrentUser,
      saved: post.savedByCurrentUser,
      shared: false,
      likesLabel: post.likes,
      commentsLabel: post.comments,
      sharesLabel: post.shares,
      savesLabel: post.saves,
      onLike: onStar,
      onComment: onComment,
      onShare: onShare,
      onSave: onSave,
      onOpenTaggedEntity: onOpenTaggedEntity,
      onMore: onMore ?? onComment,
      bottomPadding: 18,
    );
  }
}

class _PublicPostActionTile extends StatelessWidget {
  const _PublicPostActionTile({
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
          color: Colors.white.withValues(alpha: 0.64),
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
    );
  }
}

String _publicLocationLabel(CommunityProfile profile) {
  final city = profile.city.trim();
  final country = profile.country.trim();
  if (city.isEmpty && country.isEmpty) return 'Ubicación no configurada';
  if (city.isNotEmpty && country.isNotEmpty && city != country) {
    return '$city, $country';
  }
  return city.isNotEmpty ? city : country;
}
