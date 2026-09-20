import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/demo_data.dart';
import '../data/discover_data.dart';
import '../models.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_safety_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/media_permission_service.dart';
import '../services/repost_service.dart';
import '../services/store_profile_service.dart';
import '../services/video_audio_preference.dart';
import '../services/video_playback_coordinator.dart';
import '../services/drop_view_tracking.dart';
import '../theme/app_theme.dart';
import '../utils/kpop_entity_reference.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/contextual_permission_sheet.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/profile_category_chips.dart';
import '../widgets/premium_form_shell.dart';
import '../widgets/safety_report_sheet.dart';
import '../widgets/artist_tag_selector.dart';
import '../widgets/user_tag_selector.dart';
import '../widgets/video_loading_backdrop.dart';
import 'kpop_entity_profile_screen.dart';
import 'public_profile_screen.dart';

String formatDropViewCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final value = count / 1000;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1).replaceAll('.0', '')}K';
  }
  final value = count / 1000000;
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1).replaceAll('.0', '')}M';
}

class DropsScreen extends StatefulWidget {
  const DropsScreen({
    super.key,
    this.user,
    this.dropService = const LocalDropService(),
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.chatService = const LocalChatService(),
    this.storyService = const LocalStoryService(),
    this.fancamService = const LocalFancamService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.resetSignal = 0,
    this.initialDropId = '',
    this.showBackButton = false,
    this.isActive = true,
  });

  final AuthUser? user;
  final LocalDropService dropService;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalChatService chatService;
  final LocalStoryService storyService;
  final LocalFancamService fancamService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;
  final int resetSignal;
  final String initialDropId;
  final bool showBackButton;
  final bool isActive;

  @override
  State<DropsScreen> createState() => _DropsScreenState();
}

class _DropsScreenState extends State<DropsScreen> {
  final _pageController = PageController();
  final Set<String> _starredDrops = {};
  final Set<String> _savedDrops = {};
  final Set<String> _loadedStarredDrops = {};
  final Set<String> _loadedSavedDrops = {};
  final Set<String> _busyDropActions = {};
  final Map<String, List<PostComment>> _commentsByDrop = {};
  final Map<String, int> _commentAdditions = {};
  final Map<String, int> _commentRemovals = {};
  final Map<String, int> _likeAdjustments = {};
  final Set<String> _repostedDrops = {};
  List<DropClip> _localDrops = [];
  final Set<String> _blockedUserIds = {};
  int _activeIndex = 0;
  bool _muted = true;
  bool _loadingDrops = true;
  bool _publishingDrop = false;
  String _appliedInitialDropId = '';
  int _autoplaySignal = 0;
  DropFeedMode _feedMode = DropFeedMode.forYou;
  late final RepostService _repostService;

  @override
  void initState() {
    super.initState();
    if (!widget.dropService.usesRealDrops) {
      _repostService = LocalRepostService();
    } else {
      try {
        _repostService = SupabaseRepostService();
      } catch (_) {
        // Isolated widget tests can use a real-drop-shaped fake without
        // bootstrapping Supabase; production receives the real service.
        _repostService = LocalRepostService();
      }
    }
    LocalDropService.revision.addListener(_restoreDropState);
    LocalSafetyService.revision.addListener(_restoreDropState);
    VideoAudioPreference.muted.addListener(_syncVideoAudioPreference);
    _muted = VideoAudioPreference.muted.value;
    if (widget.isActive) _autoplaySignal = 1;
    _restoreDropState();
  }

  @override
  void dispose() {
    LocalDropService.revision.removeListener(_restoreDropState);
    LocalSafetyService.revision.removeListener(_restoreDropState);
    VideoAudioPreference.muted.removeListener(_syncVideoAudioPreference);
    _pageController.dispose();
    super.dispose();
  }

  void _syncVideoAudioPreference() {
    if (!mounted) return;
    setState(() => _muted = VideoAudioPreference.muted.value);
  }

  @override
  void didUpdateWidget(covariant DropsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) _resetToTop();
    if (oldWidget.initialDropId != widget.initialDropId) {
      _appliedInitialDropId = '';
    }
    if (!oldWidget.isActive && widget.isActive) {
      _autoplaySignal++;
    }
  }

  void _resetToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      _pageController.jumpToPage(0);
      if (mounted && _activeIndex != 0) setState(() => _activeIndex = 0);
    });
  }

  void _scheduleInitialDropJump(List<DropClip> visibleDrops) {
    final initialDropId = widget.initialDropId.trim();
    if (initialDropId.isEmpty || _appliedInitialDropId == initialDropId) return;
    final index = visibleDrops.indexWhere(
      (clip) => _dropId(clip) == initialDropId,
    );
    if (index < 0) return;
    _appliedInitialDropId = initialDropId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(index);
      if (_activeIndex != index) {
        setState(() => _activeIndex = index);
      }
    });
  }

  Future<void> _restoreDropState() async {
    if (_localDrops.isEmpty && mounted) {
      setState(() => _loadingDrops = true);
    }
    try {
      final local = await widget.dropService.restoreDrops(feedMode: _feedMode);
      final liked = await widget.dropService.restoreLikedDropIds();
      final saved = await widget.dropService.restoreSavedDropIds();
      final reposted = <String>{};
      if (widget.dropService.usesRealDrops) {
        final states = await Future.wait(
          local.map(
            (drop) => _repostService.hasReposted(
              contentType: RepostContentType.drop,
              contentId: _dropId(drop),
            ),
          ),
        );
        for (var index = 0; index < states.length; index++) {
          if (states[index]) reposted.add(_dropId(local[index]));
        }
      }
      final blocked = await widget.safetyService.restoreBlockedUserIds();
      if (!mounted) return;
      setState(() {
        _localDrops = local;
        _blockedUserIds
          ..clear()
          ..addAll(blocked);
        _starredDrops
          ..clear()
          ..addAll(liked);
        _savedDrops
          ..clear()
          ..addAll(saved);
        _repostedDrops
          ..clear()
          ..addAll(reposted);
        _loadedStarredDrops
          ..clear()
          ..addAll(liked);
        _loadedSavedDrops
          ..clear()
          ..addAll(saved);
        _likeAdjustments.clear();
        _commentAdditions.clear();
        _commentRemovals.clear();
        _loadingDrops = false;
      });
    } catch (error) {
      debugPrint('DROP_FEED_ERROR restore error=$error');
      if (!mounted) return;
      setState(() => _loadingDrops = false);
    }
  }

  List<DropClip> get _visibleDrops {
    final source = widget.dropService.usesRealDrops
        ? _localDrops
        : [..._localDrops, ...drops];
    final visible = source
        .where((clip) => !_blockedUserIds.contains(clip.creatorId))
        .toList(growable: false);
    if (_feedMode != DropFeedMode.viral) return visible;
    return [...visible]
      ..sort((a, b) {
        final views = b.viewCount.compareTo(a.viewCount);
        if (views != 0) return views;
        return (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        );
      });
  }

  String _dropId(DropClip clip) {
    if (clip.id.isNotEmpty) return clip.id;
    return clip.title.toLowerCase().replaceAll(' ', '-');
  }

  CommunityProfile _creatorFor(DropClip clip) {
    if (widget.dropService.usesRealDrops ||
        clip.creatorAvatarAsset.isNotEmpty) {
      return CommunityProfile(
        id: clip.creatorId,
        name: clip.creatorName.isEmpty ? 'Tu perfil' : clip.creatorName,
        username: clip.creator,
        city: clip.location.isEmpty
            ? 'Ubicación no configurada'
            : clip.location,
        country: '',
        fandom: clip.artist,
        favoriteGroup: clip.artist,
        bio: 'Creador/a de drops en HallyuHub.',
        avatarAsset: clip.creatorAvatarAsset.isEmpty
            ? 'assets/demo-users/user-01.jpg'
            : clip.creatorAvatarAsset,
        followers: '0',
        posts: '1',
        colors: const [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
        online: true,
      );
    }
    return demoProfiles.firstWhere(
      (profile) => profile.username == clip.creator,
      orElse: () => demoProfiles.first,
    );
  }

  AuthUser get _fallbackAuthor => const AuthUser(
    name: 'Tu perfil',
    email: 'demo@hallyuhub.local',
    username: '@tu.hallyu',
    country: '',
    fandom: 'ARMY',
    favoriteGroup: 'BTS',
    bio: 'Compartiendo drops en HallyuHub.',
    avatarAsset: 'assets/demo-users/user-01.jpg',
  );

  AuthUser get _dropAuthor => widget.user ?? _fallbackAuthor;

  Future<void> _toggleStar(DropClip clip) async {
    final id = _dropId(clip);
    if (_busyDropActions.contains('like-$id')) return;
    final wasStarred = _starredDrops.contains(id);
    final nextStarred = !wasStarred;
    setState(() {
      _busyDropActions.add('like-$id');
      if (nextStarred) {
        _starredDrops.add(id);
      } else {
        _starredDrops.remove(id);
      }
      _likeAdjustments[id] =
          (nextStarred ? 1 : 0) - (_loadedStarredDrops.contains(id) ? 1 : 0);
    });
    try {
      await widget.dropService.setDropLiked(id, nextStarred);
      if (!mounted) return;
      _showSnack(nextStarred ? 'Estrella agregada' : 'Estrella quitada');
      await _restoreDropState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasStarred) {
          _starredDrops.add(id);
        } else {
          _starredDrops.remove(id);
        }
        _likeAdjustments.remove(id);
      });
      _showSnack(_dropError(error));
    } finally {
      if (mounted) {
        setState(() => _busyDropActions.remove('like-$id'));
      }
    }
  }

  Future<void> _toggleSaved(DropClip clip) async {
    final id = _dropId(clip);
    if (_busyDropActions.contains('save-$id')) return;
    final wasSaved = _savedDrops.contains(id);
    final nextSaved = !wasSaved;
    setState(() {
      _busyDropActions.add('save-$id');
      if (nextSaved) {
        _savedDrops.add(id);
      } else {
        _savedDrops.remove(id);
      }
    });
    try {
      await widget.dropService.setDropSaved(id, nextSaved);
      if (!mounted) return;
      _showSnack(nextSaved ? 'Drop guardado' : 'Guardado quitado');
      await _restoreDropState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedDrops.add(id);
        } else {
          _savedDrops.remove(id);
        }
      });
      _showSnack(_dropError(error));
    } finally {
      if (mounted) {
        setState(() => _busyDropActions.remove('save-$id'));
      }
    }
  }

  Future<void> _toggleRepost(DropClip clip) async {
    final id = _dropId(clip);
    final actionKey = 'repost-$id';
    if (_busyDropActions.contains(actionKey)) return;
    final wasReposted = _repostedDrops.contains(id);
    setState(() => _busyDropActions.add(actionKey));
    try {
      if (wasReposted) {
        await _repostService.removeRepost(
          contentType: RepostContentType.drop,
          contentId: id,
        );
        if (mounted) {
          setState(() => _repostedDrops.remove(id));
          _showSnack('Repost quitado');
        }
      } else {
        await _repostService.createRepost(
          contentType: RepostContentType.drop,
          contentId: id,
        );
        if (mounted) {
          setState(() => _repostedDrops.add(id));
          _showSnack('Drop reposteado a tus seguidores');
        }
      }
    } catch (error) {
      if (mounted) _showSnack(_dropError(error));
    } finally {
      if (mounted) setState(() => _busyDropActions.remove(actionKey));
    }
  }

  List<PostComment> _commentsFor(DropClip clip) {
    return _commentsByDrop.putIfAbsent(
      _dropId(clip),
      () => widget.dropService.usesRealDrops
          ? <PostComment>[]
          : [
              const PostComment(
                author: 'Vale Dance',
                username: '@vale.dance',
                avatarAsset: 'assets/demo-users/ai-agus-han.png',
                body: 'El cierre del challenge quedó increíble.',
                time: 'Hace 12 min',
              ),
            ],
    );
  }

  Future<void> _openComments(DropClip clip) async {
    final id = _dropId(clip);
    var initialComments = _commentsByDrop[id];
    if (initialComments == null) {
      try {
        initialComments = await widget.dropService.restoreComments(id);
      } catch (error) {
        if (!mounted) return;
        _showSnack(_dropError(error));
        return;
      }
      if (!mounted) return;
      if (!widget.dropService.usesRealDrops && initialComments.isEmpty) {
        initialComments = _commentsFor(clip);
      }
      _commentsByDrop[id] = initialComments;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        threadId: id,
        subtitle: clip.title,
        initialComments: initialComments!,
        currentUserName: _dropAuthor.name,
        currentUsername: _dropAuthor.username,
        currentUserAvatar: _dropAuthor.avatarAsset,
        safetyService: widget.safetyService,
        reportContentType: 'drop_comment',
        onSubmitComment: (body, parentId) => widget.dropService.addComment(
          author: _dropAuthor,
          dropId: id,
          body: body,
          parentId: parentId,
        ),
        onDeleteComment: (comment) =>
            widget.dropService.deleteComment(dropId: id, commentId: comment.id),
        onOpenAuthor: _openCommentAuthor,
        onChanged: (comments) {
          setState(() => _commentsByDrop[id] = comments);
        },
        onCommentAdded: () {
          setState(() {
            _commentAdditions.update(
              id,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          });
        },
        onCommentsRemoved: (count) {
          setState(() {
            _commentRemovals.update(
              id,
              (value) => value + count,
              ifAbsent: () => count,
            );
          });
        },
      ),
    );
  }

  void _openCreatorProfile(DropClip clip) {
    final creator = _creatorFor(clip);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          profile: creator,
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
    } catch (_) {
      if (!mounted) return;
      _showSnack('No encontramos ese perfil.');
    }
  }

  void _openCommentAuthor(PostComment comment) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          profile: CommunityProfile(
            id: comment.authorId.isEmpty ? comment.username : comment.authorId,
            name: comment.author,
            username: comment.username,
            city: '',
            country: '',
            fandom: 'HallyuHub',
            favoriteGroup: '',
            bio: 'Perfil de ${comment.author}',
            avatarAsset: comment.avatarAsset,
            followers: '',
            posts: '',
            colors: const [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
          ),
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

  Future<void> _reportDrop(DropClip clip) async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      title: 'Reportar Drop: ${clip.title}',
      contentType: 'drop',
      contentId: _dropId(clip),
      reportedUserId: clip.creatorId,
      metadata: {
        'caption': clip.title,
        'creator': clip.creator,
        'artist': clip.artist,
      },
    );
    if (!mounted || !sent) return;
    _showSnack('Gracias. Recibimos tu reporte y lo vamos a revisar.');
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

  Future<void> _openDropEntity(DropClip clip) async {
    final entity = await resolveKpopEntityReference(
      artistTagService: widget.artistTagService,
      id: clip.artistId,
      name: clip.artist,
      knownEntities: clip.taggedEntities,
    );
    if (!mounted) return;
    if (entity == null) {
      _showSnack('No pudimos encontrar el perfil de ${clip.artist}.');
      return;
    }
    _openKpopEntity(entity);
  }

  Future<void> _openCreateDrop() async {
    if (_publishingDrop) return;
    final result = await showModalBottomSheet<_DropUploadResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DropUploadSheet(
        currentUser: widget.user,
        followService: widget.followService,
        artistTagService: widget.artistTagService,
      ),
    );
    if (result == null) return;
    setState(() => _publishingDrop = true);
    DropClip publishedDrop;
    try {
      publishedDrop = await widget.dropService.publish(
        author: _dropAuthor,
        videoPath: result.videoPath,
        videoBytes: result.videoBytes,
        videoFileName: result.videoFileName,
        videoMimeType: result.videoMimeType,
        caption: result.caption,
        artist: result.artistName,
        groupId: result.groupId,
        artistId: result.artistId,
        filter: result.filter,
        location: result.location,
        audio: result.audio,
        videoDurationSeconds: result.videoDurationSeconds,
        videoTrimStartSeconds: result.videoTrimStartSeconds,
        videoTrimEndSeconds: result.videoTrimEndSeconds,
        optimizedForUpload: result.optimizedForUpload,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _publishingDrop = false);
      _showSnack(_dropError(error));
      return;
    }
    final categoriesSaved = await _saveProfileCategories(
      userId: publishedDrop.creatorId,
      contentType: ProfileContentType.drop,
      contentId: _dropId(publishedDrop),
      categories: result.profileCategories,
    );
    await _saveUserTags(
      contentType: ProfileContentType.drop,
      contentId: _dropId(publishedDrop),
      taggedUsers: result.taggedUsers,
    );
    await _saveArtistTags(
      contentType: ProfileContentType.drop,
      contentId: _dropId(publishedDrop),
      taggedEntities: result.taggedEntities,
    );
    await _restoreDropState();
    if (!mounted) return;
    setState(() => _publishingDrop = false);
    if (categoriesSaved) _showSnack('Drop publicado');
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
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
      debugPrint('PROFILE_CATEGORY_SAVE_ERROR drop error=$error');
      if (!mounted) return false;
      _showSnack('Drop publicado. No pudimos guardarlo en los globitos.');
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
        'CONTENT_USER_TAGS_SAVE_ERROR drops $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack('Drop publicado, pero no pudimos guardar las etiquetas.');
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
        'CONTENT_ARTIST_TAGS_SAVE_ERROR drops $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack(
        'Drop publicado, pero no pudimos guardar artistas etiquetados.',
      );
    }
  }

  Future<void> _deleteDrop(DropClip clip) async {
    if (!clip.isOwn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Eliminar Drop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Se va a quitar este Drop de tu feed. Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.dropService.deleteDrop(_dropId(clip));
      await _restoreDropState();
      if (!mounted) return;
      _showSnack('Drop eliminado');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_dropError(error));
    }
  }

  String _dropLikeLabel(DropClip clip) {
    final id = _dropId(clip);
    final base = int.tryParse(clip.likes) ?? 0;
    final value = (base + (_likeAdjustments[id] ?? 0)).clamp(0, 999999);
    return '$value';
  }

  String _dropCommentLabel(DropClip clip) {
    final id = _dropId(clip);
    final base = int.tryParse(clip.comments) ?? 0;
    final value =
        (base + (_commentAdditions[id] ?? 0) - (_commentRemovals[id] ?? 0))
            .clamp(0, 999999);
    return '$value';
  }

  String _dropViewsLabel(DropClip clip) {
    return widget.dropService.usesRealDrops
        ? formatDropViewCount(clip.viewCount)
        : clip.views;
  }

  String _dropError(Object error) {
    if (error is DropServiceException && error.message.isNotEmpty) {
      return error.message;
    }
    _log('DROP_UPLOAD_ERROR', {'step': 'ui_unhandled', 'error': '$error'});
    return 'No pudimos completar la acción en Drops. Probá de nuevo en unos segundos.';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
        ),
      );
  }

  void _log(String event, Map<String, Object?> data) {
    debugPrint(
      '$event ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }

  void _recordView(DropClip clip, String playbackSessionId) {
    if (!widget.dropService.usesRealDrops || clip.id.isEmpty) return;
    unawaited(
      widget.dropService
          .recordView(dropId: clip.id, playbackSessionId: playbackSessionId)
          .catchError((error) {
            debugPrint('DROP_VIEW_ERROR id=${clip.id} error=$error');
          }),
    );
  }

  Future<void> _changeFeedMode(DropFeedMode mode) async {
    if (_feedMode == mode) return;
    setState(() {
      _feedMode = mode;
      _loadingDrops = true;
    });
    _resetToTop();
    await _restoreDropState();
  }

  @override
  Widget build(BuildContext context) {
    final visibleDrops = _visibleDrops;
    _scheduleInitialDropJump(visibleDrops);
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            const _DropAura(),
            if (_loadingDrops && visibleDrops.isEmpty)
              const _DropLoadingState()
            else if (visibleDrops.isEmpty)
              _EmptyDropsState(onCreate: _openCreateDrop)
            else
              PageView.builder(
                key: const ValueKey('drops-reels-feed'),
                controller: _pageController,
                scrollDirection: Axis.vertical,
                pageSnapping: true,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemCount: visibleDrops.length,
                itemBuilder: (context, index) {
                  final clip = visibleDrops[index];
                  final id = _dropId(clip);
                  return _DropReelCard(
                    key: ValueKey('drop-reel-$id'),
                    clip: clip,
                    creator: _creatorFor(clip),
                    selected: index == _activeIndex,
                    screenActive: widget.isActive,
                    autoplaySignal: _autoplaySignal,
                    muted: _muted,
                    starred: _starredDrops.contains(id),
                    saved: _savedDrops.contains(id),
                    reposted: _repostedDrops.contains(id),
                    likesLabel: _dropLikeLabel(clip),
                    commentsLabel: _dropCommentLabel(clip),
                    onToggleSound: () =>
                        VideoAudioPreference.setMuted(!_muted, source: 'drops'),
                    onStar: () => _toggleStar(clip),
                    onSave: () => _toggleSaved(clip),
                    onRepost: () => _toggleRepost(clip),
                    onComment: () => _openComments(clip),
                    onReport: () => _reportDrop(clip),
                    onDelete: clip.isOwn ? () => _deleteDrop(clip) : null,
                    onProfile: () => _openCreatorProfile(clip),
                    onOpenTaggedPerson: _openTaggedUsername,
                    onOpenTaggedEntity: _openKpopEntity,
                    onOpenPrimaryEntity: () => _openDropEntity(clip),
                    viewsLabel: _dropViewsLabel(clip),
                    onViews: () =>
                        _showSnack('${_dropViewsLabel(clip)} reproducciones'),
                    onView: (sessionId) => _recordView(clip, sessionId),
                  );
                },
              ),
            if (widget.showBackButton)
              Positioned(
                left: 18,
                top: 18,
                child: FloatingActionButton.small(
                  heroTag: 'drops-profile-back-button',
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Volver',
                  backgroundColor: Colors.black.withValues(alpha: 0.52),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            if (!widget.showBackButton && widget.isActive)
              Positioned(
                left: 16,
                right: 16,
                top: 72,
                child: const HallyFeatureTip(
                  featureId: 'drops_intro',
                  title: 'Descubrí Drops con Hally ✨',
                  message:
                      'Explorá videos verticales de fans y momentos de tus artistas.',
                  mascotAsset: 'assets/brand/hally_mascot_wave_transparent.png',
                  compact: true,
                ),
              ),
            Positioned(
              left: widget.showBackButton ? 68 : 16,
              right: 68,
              top: 16,
              child: _DropFeedModeSelector(
                selected: _feedMode,
                onChanged: _changeFeedMode,
              ),
            ),
            if (_publishingDrop)
              Container(
                color: AppTheme.night.withValues(alpha: 0.74),
                child: const Center(child: _DropPublishingStatus()),
              ),
            if (!widget.showBackButton)
              Positioned(
                right: 18,
                top: 18,
                child: FloatingActionButton.small(
                  key: const ValueKey('drops-new-button'),
                  heroTag: 'drops-new-button',
                  onPressed: _publishingDrop ? null : _openCreateDrop,
                  tooltip: 'Nuevo drop',
                  backgroundColor: AppTheme.rose,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropFeedModeSelector extends StatelessWidget {
  const _DropFeedModeSelector({required this.selected, required this.onChanged});

  final DropFeedMode selected;
  final ValueChanged<DropFeedMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.cyan.withValues(alpha: .32)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mode('Para ti', DropFeedMode.forYou),
              _mode('Más virales', DropFeedMode.viral),
              _mode('Siguiendo', DropFeedMode.following),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mode(String label, DropFeedMode mode) {
    final active = selected == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.violet.withValues(alpha: .9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: active ? 1 : .72),
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyDropsState extends StatelessWidget {
  const _EmptyDropsState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.rose.withValues(alpha: 0.16),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.rose, AppTheme.cyan],
                  ),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Todavía no hay Drops por acá',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuando alguien comparta un clip corto del fandom, va a aparecer en este feed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Subir primer Drop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropPublishingStatus extends StatelessWidget {
  const _DropPublishingStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.28)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.rose,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Subiendo Drop...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DropLoadingState extends StatelessWidget {
  const _DropLoadingState();

  @override
  Widget build(BuildContext context) {
    return const VideoLoadingBackdrop(label: '');
  }
}

class _DropReelCard extends StatelessWidget {
  const _DropReelCard({
    super.key,
    required this.clip,
    required this.creator,
    required this.selected,
    required this.screenActive,
    required this.autoplaySignal,
    required this.muted,
    required this.starred,
    required this.saved,
    required this.reposted,
    required this.likesLabel,
    required this.commentsLabel,
    required this.viewsLabel,
    required this.onToggleSound,
    required this.onStar,
    required this.onSave,
    required this.onRepost,
    required this.onComment,
    required this.onReport,
    required this.onDelete,
    required this.onProfile,
    required this.onOpenTaggedPerson,
    required this.onOpenTaggedEntity,
    required this.onOpenPrimaryEntity,
    required this.onViews,
    required this.onView,
  });

  final DropClip clip;
  final CommunityProfile creator;
  final bool selected;
  final bool screenActive;
  final int autoplaySignal;
  final bool muted;
  final bool starred;
  final bool saved;
  final bool reposted;
  final String likesLabel;
  final String commentsLabel;
  final String viewsLabel;
  final VoidCallback onToggleSound;
  final VoidCallback onStar;
  final VoidCallback onSave;
  final VoidCallback onRepost;
  final VoidCallback onComment;
  final VoidCallback onReport;
  final VoidCallback? onDelete;
  final VoidCallback onProfile;
  final ValueChanged<String> onOpenTaggedPerson;
  final ValueChanged<KpopEntity> onOpenTaggedEntity;
  final VoidCallback onOpenPrimaryEntity;
  final VoidCallback onViews;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    final caption = clip.caption.isEmpty ? clip.title : clip.caption;
    final primaryEntity = _primaryTaggedEntity(clip);
    final secondaryEntities = primaryEntity == null
        ? clip.taggedEntities
        : clip.taggedEntities
              .where((entity) => entity.id != primaryEntity.id)
              .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _DropMedia(
              clip: clip,
              selected: selected,
              screenActive: screenActive,
              autoplaySignal: autoplaySignal,
              muted: muted,
              onView: onView,
            ),
            _DropFilterOverlay(filter: clip.filter),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DropAction(
                      key: ValueKey('drop-star-${clip.title}'),
                      icon: starred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      label: likesLabel,
                      active: starred,
                      tooltip: starred ? 'Quitar estrella' : 'Dar estrella',
                      onPressed: onStar,
                    ),
                    _DropAction(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: saved ? 'Guardado' : 'Guardar',
                      active: saved,
                      tooltip: saved ? 'Quitar guardado' : 'Guardar Drop',
                      onPressed: onSave,
                    ),
                    _DropAction(
                      key: ValueKey('drop-comment-${clip.title}'),
                      icon: Icons.mode_comment_outlined,
                      label: commentsLabel,
                      tooltip: 'Comentar',
                      onPressed: onComment,
                    ),
                    if (!clip.isOwn)
                      _DropAction(
                        icon: Icons.flag_outlined,
                        label: 'Reportar',
                        tooltip: 'Reportar Drop',
                        onPressed: onReport,
                      ),
                    if (onDelete != null)
                      _DropAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Borrar',
                        tooltip: 'Eliminar Drop',
                        onPressed: onDelete!,
                      ),
                    _DropAction(
                      icon: reposted
                          ? Icons.repeat_on_rounded
                          : Icons.repeat_rounded,
                      label: reposted ? 'Reposteado' : 'Repost',
                      active: reposted,
                      tooltip: reposted ? 'Quitar repost' : 'Repostear Drop',
                      onPressed: onRepost,
                    ),
                    _DropAction(
                      icon: Icons.visibility_rounded,
                      label: viewsLabel,
                      tooltip: 'Ver reproducciones',
                      onPressed: onViews,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 70,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onProfile,
                    child: Row(
                      children: [
                        HubAvatar(
                          asset: creator.avatarAsset,
                          size: 38,
                          isLive: creator.online || clip.isOwn,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                creator.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                clip.creator,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NeonTag(
                        clip.artist,
                        key: const ValueKey('drop-primary-entity-tag'),
                        onTap: primaryEntity == null
                            ? onOpenPrimaryEntity
                            : () => onOpenTaggedEntity(primaryEntity),
                      ),
                      if (clip.filter != 'Original') _NeonTag(clip.filter),
                      if (clip.location.isNotEmpty) _NeonTag(clip.location),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      height: 1.2,
                    ),
                  ),
                  if (clip.taggedPeople.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TaggedVideoPeopleRow(
                      usernames: clip.taggedPeople,
                      onOpen: onOpenTaggedPerson,
                    ),
                  ],
                  if (secondaryEntities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TaggedVideoEntityRow(
                      entities: secondaryEntities,
                      onOpen: onOpenTaggedEntity,
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _DropSoundPill(muted: muted, onPressed: onToggleSound),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          clip.audio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (clip.repostedByUsername.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      '↻ Reposteado por ${clip.repostedByUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.cyan.withValues(alpha: .9),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
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

  KpopEntity? _primaryTaggedEntity(DropClip clip) {
    final entities = clip.taggedEntities
        .where((entity) => entity.id.trim().isNotEmpty)
        .toList(growable: false);
    if (entities.isEmpty) return null;

    final storedEntityId = clip.artistId.trim();
    if (storedEntityId.isNotEmpty) {
      for (final entity in entities) {
        if (entity.id == storedEntityId) return entity;
      }
    }

    final artistKey = _entityTagKey(clip.artist);
    if (artistKey.isEmpty) return null;
    final matches = entities
        .where((entity) {
          if (_entityTagKey(entity.name) == artistKey) return true;
          return entity.aliases.any(
            (alias) => _entityTagKey(alias) == artistKey,
          );
        })
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  String _entityTagKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _TaggedVideoPeopleRow extends StatelessWidget {
  const _TaggedVideoPeopleRow({required this.usernames, required this.onOpen});

  final List<String> usernames;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final cleaned = usernames
        .map((username) => username.trim())
        .where((username) => username.isNotEmpty)
        .map((username) => username.startsWith('@') ? username : '@$username')
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Con',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        ...cleaned.map(
          (username) => InkWell(
            onTap: () => onOpen(username),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.cyan.withValues(alpha: .36)),
              ),
              child: Text(
                username,
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaggedVideoEntityRow extends StatelessWidget {
  const _TaggedVideoEntityRow({required this.entities, required this.onOpen});

  final List<KpopEntity> entities;
  final ValueChanged<KpopEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    final cleaned = <String, KpopEntity>{};
    for (final entity in entities) {
      if (entity.id.trim().isEmpty || entity.name.trim().isEmpty) continue;
      cleaned.putIfAbsent(entity.id, () => entity);
    }
    if (cleaned.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Etiquetado',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        ...cleaned.values.map(
          (entity) => InkWell(
            onTap: () => onOpen(entity),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.rose.withValues(alpha: .26),
                    AppTheme.violet.withValues(alpha: .2),
                    AppTheme.cyan.withValues(alpha: .18),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.rose.withValues(alpha: .36)),
              ),
              child: Text(
                entity.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropMedia extends StatefulWidget {
  const _DropMedia({
    required this.clip,
    required this.selected,
    required this.screenActive,
    required this.autoplaySignal,
    required this.muted,
    required this.onView,
  });

  final DropClip clip;
  final bool selected;
  final bool screenActive;
  final int autoplaySignal;
  final bool muted;
  final ValueChanged<String> onView;

  @override
  State<_DropMedia> createState() => _DropMediaState();
}

class _DropMediaState extends State<_DropMedia> {
  final Object _playbackOwner = Object();
  VideoPlayerController? _controller;
  Timer? _audioNoticeTimer;
  String _audioNotice = '';
  bool _ready = false;
  bool _playing = false;
  bool _videoError = false;
  String _playbackSessionId = '';
  late final DropViewSessionTracker _viewTracker;

  @override
  void initState() {
    super.initState();
    _viewTracker = DropViewSessionTracker();
    _setupVideo();
  }

  @override
  void didUpdateWidget(covariant _DropMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.videoPath != widget.clip.videoPath) {
      _disposeController();
      _setupVideo();
      return;
    }
    if (oldWidget.muted != widget.muted) {
      unawaited(_applyVolume(widget.muted, reason: 'rebuild'));
    }
    final leftVisibleItem =
        (oldWidget.screenActive && !widget.screenActive) ||
        (oldWidget.selected && !widget.selected);
    final enteredSelectedItem =
        widget.screenActive &&
        widget.selected &&
        ((!oldWidget.screenActive && widget.screenActive) ||
            (!oldWidget.selected && widget.selected) ||
            oldWidget.autoplaySignal != widget.autoplaySignal);
    if (leftVisibleItem) {
      unawaited(_pausePlayback(reason: 'inactive'));
    } else if (enteredSelectedItem) {
      unawaited(_startPlayback(reason: 'selected'));
    }
  }

  @override
  void dispose() {
    _audioNoticeTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  void _setupVideo() {
    if (!widget.clip.hasVideo) return;
    _logAudio('VIDEO_AUDIO_INIT', {
      'muted': widget.muted,
      'active': widget.screenActive && widget.selected,
    });
    _videoError = false;
    final controller = VideoPlayerController.networkUrl(
      _videoUri(widget.clip.videoPath),
    );
    _controller = controller;
    controller.addListener(_checkViewThreshold);
    unawaited(
      controller
          .initialize()
          .then((_) async {
            if (!mounted) return;
            await controller.setLooping(true);
            await controller.setVolume(widget.muted ? 0 : 1);
            if (!mounted) return;
            setState(() {
              _ready = true;
              _playing = false;
            });
            if (widget.screenActive && widget.selected) {
              await _startPlayback(reason: 'init');
            }
            _logAudio('VIDEO_VOLUME_STATE', {
              'volume': widget.muted ? 0 : 1,
              'reason': 'init',
            });
          })
          .catchError((Object error) {
            _logAudio('VIDEO_AUDIO_ERROR', {
              'step': 'initialize',
              'error': '$error',
            });
            if (!mounted) return;
            setState(() {
              _ready = false;
              _videoError = true;
            });
          }),
    );
  }

  void _disposeController() {
    VideoPlaybackCoordinator.release(_playbackOwner);
    final controller = _controller;
    _controller = null;
    _ready = false;
    _videoError = false;
    if (controller != null) {
      controller.removeListener(_checkViewThreshold);
      unawaited(controller.dispose());
    }
  }

  Future<void> _startPlayback({required String reason}) async {
    final controller = _controller;
    if (controller == null ||
        !_ready ||
        !widget.screenActive ||
        !widget.selected) {
      return;
    }
    final claimed = await VideoPlaybackCoordinator.claim(
      owner: _playbackOwner,
      source: 'drops',
      pause: () => _pausePlayback(reason: 'another_video', release: false),
    );
    if (!claimed ||
        !mounted ||
        !identical(controller, _controller) ||
        !widget.screenActive ||
        !widget.selected) {
      return;
    }
    try {
      _playbackSessionId = newDropPlaybackSessionId();
      _viewTracker.start();
      await controller.play();
      if (mounted) setState(() => _playing = true);
      _logAudio('VIDEO_PLAYBACK_START', {'reason': reason});
    } catch (error) {
      VideoPlaybackCoordinator.release(_playbackOwner);
      _logAudio('VIDEO_AUDIO_ERROR', {'step': 'play', 'error': '$error'});
    }
  }

  void _checkViewThreshold() {
    final controller = _controller;
    if (controller == null || !_playing || _playbackSessionId.isEmpty) return;
    final value = controller.value;
    if (!_viewTracker.shouldRecord(
      position: value.position,
      duration: value.duration,
    )) {
      return;
    }
    widget.onView(_playbackSessionId);
  }

  Future<void> _pausePlayback({
    required String reason,
    bool release = true,
  }) async {
    final controller = _controller;
    if (release) VideoPlaybackCoordinator.release(_playbackOwner);
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pause();
      } catch (error) {
        _logAudio('VIDEO_AUDIO_ERROR', {'step': 'pause', 'error': '$error'});
      }
    }
    if (mounted && _playing) setState(() => _playing = false);
    _logAudio('VIDEO_PLAYBACK_PAUSE', {'reason': reason});
  }

  void _togglePlayback() {
    if (!_ready || !widget.screenActive || !widget.selected) return;
    if (_playing) {
      unawaited(_pausePlayback(reason: 'user'));
    } else {
      unawaited(_startPlayback(reason: 'user'));
    }
  }

  Future<void> _applyVolume(bool muted, {required String reason}) async {
    final controller = _controller;
    _logAudio('VIDEO_MUTED_STATE', {
      'muted': muted,
      'ready': _ready,
      'reason': reason,
    });
    if (controller == null || !_ready) return;
    final volume = muted ? 0.0 : 1.0;
    try {
      await controller.setVolume(volume);
      _logAudio('VIDEO_VOLUME_STATE', {'volume': volume, 'reason': reason});
    } catch (error) {
      _logAudio('VIDEO_AUDIO_ERROR', {'step': 'set_volume', 'error': '$error'});
      _showAudioNotice(
        'No pudimos activar el audio. Tocá play o probá de nuevo.',
      );
    }
  }

  void _showAudioNotice(String message) {
    if (!mounted) return;
    setState(() => _audioNotice = message);
    _audioNoticeTimer?.cancel();
    _audioNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _audioNotice = '');
    });
  }

  void _logAudio(String event, Map<String, Object?> data) {
    final id = widget.clip.id.isEmpty ? widget.clip.title : widget.clip.id;
    debugPrint(
      '$event source=drops id=$id ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && _ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else if (controller != null && !_videoError)
            const VideoLoadingBackdrop(label: '')
          else if (_videoError)
            const VideoErrorBackdrop()
          else
            Image.asset(widget.clip.imageAsset, fit: BoxFit.cover),
          if (controller == null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          if (controller != null && _ready && !_playing)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 62,
              ),
            ),
          if (_videoError)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.rose.withValues(alpha: 0.32),
                  ),
                ),
                child: const Text(
                  'No pudimos reproducir este video en este navegador.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (_audioNotice.isNotEmpty)
            Positioned(
              left: 18,
              right: 18,
              top: 68,
              child: _DropInlineNotice(message: _audioNotice),
            ),
        ],
      ),
    );
  }
}

class _DropSoundPill extends StatelessWidget {
  const _DropSoundPill({required this.muted, required this.onPressed});

  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('drop-sound-toggle'),
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                muted ? 'Activar audio' : 'Audio activo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropInlineNotice extends StatelessWidget {
  const _DropInlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DropUploadSheet extends StatefulWidget {
  const _DropUploadSheet({
    required this.currentUser,
    required this.followService,
    required this.artistTagService,
  });

  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalArtistTagService artistTagService;

  @override
  State<_DropUploadSheet> createState() => _DropUploadSheetState();
}

class _DropUploadSheetState extends State<_DropUploadSheet> {
  static const _maxDropDuration = Duration(minutes: 5);
  static const _filters = [
    'Original',
    'Hallyu Glow',
    'Neon Stage',
    'Soft Pastel',
    'Concert Lights',
    'Black Pink',
    'Purple Galaxy',
  ];

  final _picker = ImagePicker();
  final _permissionService = const MediaPermissionService();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController(text: 'Santiago');
  String _videoPath = '';
  Uint8List? _videoBytes;
  String _videoFileName = '';
  String _videoMimeType = '';
  String _selectedArtistId = discoverIdols.first.id;
  String _filter = _filters.first;
  String _audio = storyMusicLibrary.first.label;
  Duration? _videoDuration;
  bool _processingVideo = false;
  bool _optimizedForUpload = false;
  Set<ProfileContentCategory> _selectedProfileCategories = {};
  List<CommunityProfile> _selectedTaggedUsers = const [];
  List<KpopEntity> _selectedTaggedEntities = const [];
  bool _resolvingPrimaryEntity = false;
  String _videoNotice =
      'Drops acepta clips de hasta 5 minutos y 100 MB durante el acceso anticipado.';

  DiscoverIdol get _selectedIdol =>
      discoverIdols.firstWhere((idol) => idol.id == _selectedArtistId);

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_processingVideo) return;
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: source == ImageSource.camera
          ? Icons.videocam_outlined
          : Icons.video_library_outlined,
      title: source == ImageSource.camera ? 'Grabar drop' : 'Elegir video',
      detail: source == ImageSource.camera
          ? 'HallyuHub necesita cámara y micrófono para grabar el drop.'
          : 'HallyuHub necesita acceso a videos para subir el drop.',
      allowLabel: source == ImageSource.camera ? 'Permitir cámara' : 'Permitir',
      currentStatus: source == ImageSource.camera
          ? () => _permissionService.cameraStatus(microphone: true)
          : _permissionService.galleryStatus,
      request: source == ImageSource.camera
          ? () => _permissionService.requestCameraAccess(microphone: true)
          : _permissionService.requestGalleryAccess,
    );
    if (!allowed || !mounted) return;
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: _maxDropDuration,
    );
    if (picked == null || !mounted) return;
    _log('DROP_PICKED_FILE', {
      'name': picked.name,
      'mimeType': picked.mimeType ?? '',
      'path': picked.path,
    });
    final formatError = _videoFormatError(
      path: picked.path,
      fileName: picked.name,
      mimeType: picked.mimeType ?? '',
    );
    if (formatError != null) {
      setState(() {
        _videoPath = '';
        _videoBytes = null;
        _videoFileName = '';
        _videoMimeType = '';
        _processingVideo = false;
        _videoNotice = formatError;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(formatError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    setState(() {
      _videoPath = picked.path;
      _videoBytes = null;
      _videoFileName = picked.name;
      _videoMimeType = picked.mimeType ?? '';
      _videoDuration = null;
      _optimizedForUpload = false;
      _processingVideo = true;
      _videoNotice = 'Preparando video para subirlo como Drop...';
    });
    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoPath = '';
        _videoBytes = null;
        _videoFileName = '';
        _videoMimeType = '';
        _processingVideo = false;
        _videoNotice =
            'No pudimos leer este video. Probá con un clip MP4 o MOV más liviano desde galería.';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos preparar el video. Elegí otro clip e intentá nuevamente.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (bytes.lengthInBytes > LocalDropService.maxVideoBytes) {
      _log('DROP_UPLOAD_ERROR', {
        'step': 'validation',
        'error': 'file_size',
        'bytes': bytes.lengthInBytes,
      });
      if (!mounted) return;
      setState(() {
        _videoPath = '';
        _videoBytes = null;
        _videoFileName = '';
        _videoMimeType = '';
        _processingVideo = false;
        _videoNotice =
            'El video supera el límite de 100 MB del acceso anticipado.';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'El video supera el límite de 100 MB del acceso anticipado.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    _log('DROP_VIDEO_BYTES_READY', {
      'bytes': bytes.lengthInBytes,
      'fileName': picked.name,
      'mimeType': picked.mimeType ?? '',
    });
    final duration = await _readVideoDuration(picked.path);
    if (!mounted) return;
    setState(() {
      _videoBytes = bytes;
      _videoDuration = duration;
      _optimizedForUpload = duration != null && duration > _maxDropDuration;
      _processingVideo = false;
      _videoNotice = _noticeForDuration(duration);
    });
  }

  Future<Duration?> _readVideoDuration(String path) async {
    final controller = VideoPlayerController.networkUrl(_videoUri(path));
    try {
      await controller.initialize();
      return controller.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  String _noticeForDuration(Duration? duration) {
    if (duration == null) {
      return 'Video listo. No pudimos leer la duración en este dispositivo, pero podés intentar subirlo igual.';
    }
    final formatted = _formatDuration(duration);
    if (duration > _maxDropDuration) {
      return 'El video dura $formatted. Durante el acceso anticipado recortalo a 5 minutos o elegí un clip más corto antes de publicar.';
    }
    return 'Video listo: $formatted. Se subirá como Drop vertical.';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String? _videoFormatError({
    required String path,
    required String fileName,
    required String mimeType,
  }) {
    final mime = mimeType.toLowerCase().trim();
    final source = '$fileName $path'.toLowerCase();
    final extensionAllowed =
        source.contains('.mp4') ||
        source.contains('.mov') ||
        source.contains('.webm') ||
        source.contains('.m4v');
    final mimeAllowed =
        mime == 'video/mp4' ||
        mime == 'video/quicktime' ||
        mime == 'video/webm';
    if (mimeAllowed || extensionAllowed) return null;
    _log('DROP_UPLOAD_ERROR', {
      'step': 'validation',
      'error': 'unsupported_format',
      'mimeType': mimeType,
      'fileName': fileName,
    });
    return 'Formato no compatible. Probá con MP4 o MOV.';
  }

  void _log(String event, Map<String, Object?> data) {
    debugPrint(
      '$event ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }

  Future<void> _publish() async {
    if (_processingVideo || _resolvingPrimaryEntity) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Esperá un momento, estamos preparando el video.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (_videoPath.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Primero elegí o grabá un video.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (_videoDuration != null && _videoDuration! > _maxDropDuration) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('El Drop no puede superar 5 minutos por ahora.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final idol = _selectedIdol;
    setState(() => _resolvingPrimaryEntity = true);
    final primaryEntity = await _resolvePrimaryEntity(idol);
    if (!mounted) return;
    if (primaryEntity == null) {
      setState(() => _resolvingPrimaryEntity = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No encontramos ese idol en el catálogo real. Elegilo también en “Etiquetar artista, grupo o idol”.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final taggedEntities = <String, KpopEntity>{
      for (final entity in _selectedTaggedEntities) entity.id: entity,
      primaryEntity.id: primaryEntity,
    }.values.toList(growable: false);
    setState(() => _resolvingPrimaryEntity = false);
    Navigator.of(context).pop(
      _DropUploadResult(
        videoPath: _videoPath,
        videoBytes: _videoBytes,
        videoFileName: _videoFileName,
        videoMimeType: _videoMimeType,
        caption: _captionController.text.trim(),
        artistName: idol.name,
        artistId: primaryEntity.id,
        groupId: idol.groupId,
        location: _locationController.text.trim(),
        filter: _filter,
        audio: _audio,
        videoDurationSeconds: _videoDuration == null
            ? null
            : _videoDuration!.inMilliseconds / 1000,
        videoTrimStartSeconds: 0,
        videoTrimEndSeconds: _optimizedForUpload
            ? _maxDropDuration.inSeconds.toDouble()
            : null,
        optimizedForUpload: _optimizedForUpload,
        profileCategories: _selectedProfileCategories.toList(growable: false),
        taggedUsers: _selectedTaggedUsers,
        taggedEntities: taggedEntities,
      ),
    );
  }

  Future<KpopEntity?> _resolvePrimaryEntity(DiscoverIdol idol) async {
    final idolKeys = <String>{
      _dropEntityKey(idol.id),
      _dropEntityKey(idol.name),
      _dropEntityKey(idol.realName),
      _dropEntityKey(idol.fullName),
      ...idol.aliases.map(_dropEntityKey),
    }..remove('');
    final selectedMatches = _selectedTaggedEntities
        .where((entity) => _entityMatchesKeys(entity, idolKeys))
        .toList(growable: false);
    if (selectedMatches.length == 1) return selectedMatches.single;
    try {
      final results = await widget.artistTagService.searchEntities(
        query: idol.name,
        limit: 30,
      );
      final matches = results
          .where((entity) => _entityMatchesKeys(entity, idolKeys))
          .toList(growable: false);
      return matches.length == 1 ? matches.single : null;
    } catch (error) {
      debugPrint('DROP_PRIMARY_ENTITY_RESOLVE_ERROR ${idol.name} $error');
      return null;
    }
  }

  bool _entityMatchesKeys(KpopEntity entity, Set<String> targetKeys) {
    final entityKeys = <String>{
      _dropEntityKey(entity.name),
      _dropEntityKey(entity.normalizedName),
      ...entity.aliases.map(_dropEntityKey),
    }..remove('');
    return entityKeys.any(targetKeys.contains);
  }

  String _dropEntityKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF060913),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSheetHandle(),
              const SizedBox(height: 14),
              PremiumFormHero(
                title: 'Nuevo Drop',
                subtitle:
                    'Prepará el video, elegí sus etiquetas y revisalo antes de publicar.',
                icon: Icons.bolt_rounded,
                visual: PremiumFormVisual.create,
                trailing: IconButton(
                  key: const ValueKey('drop-upload-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancelar subida',
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _videoPath.isEmpty
                          ? _DropUploadPlaceholder(
                              onGallery: _processingVideo
                                  ? null
                                  : () => _pickVideo(ImageSource.gallery),
                              onCamera: _processingVideo
                                  ? null
                                  : () => _pickVideo(ImageSource.camera),
                            )
                          : _DropVideoPreview(
                              videoPath: _videoPath,
                              filter: _filter,
                            ),
                      if (_processingVideo)
                        Container(
                          color: AppTheme.night.withValues(alpha: 0.72),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.rose,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('drop-pick-gallery'),
                      onPressed: _processingVideo
                          ? null
                          : () => _pickVideo(ImageSource.gallery),
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('drop-pick-camera'),
                      onPressed: _processingVideo
                          ? null
                          : () => _pickVideo(ImageSource.camera),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Cámara'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DropUploadStatusCard(
                processing: _processingVideo,
                optimized: _optimizedForUpload,
                message: _videoNotice,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('drop-caption'),
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: challenge, outfit, stage edit...',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('drop-artist'),
                initialValue: _selectedArtistId,
                dropdownColor: AppTheme.nightSoft,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  labelText: 'Etiquetar artista',
                ),
                items: discoverIdols
                    .take(40)
                    .map(
                      (idol) => DropdownMenuItem(
                        value: idol.id,
                        child: Text('${idol.name} · ${idol.groupId}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedArtistId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('drop-music'),
                initialValue: _audio,
                dropdownColor: AppTheme.nightSoft,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(labelText: 'Música'),
                items: storyMusicLibrary
                    .map(
                      (track) => DropdownMenuItem(
                        value: track.label,
                        child: Text(track.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _audio = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('drop-filter'),
                initialValue: _filter,
                dropdownColor: AppTheme.nightSoft,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(labelText: 'Filtro'),
                items: _filters
                    .map(
                      (filter) =>
                          DropdownMenuItem(value: filter, child: Text(filter)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _filter = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('drop-location'),
                controller: _locationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Ubicación/evento',
                  hintText: 'Santiago, Palermo, Lima...',
                ),
              ),
              const SizedBox(height: 12),
              UserTagSelector(
                followService: widget.followService,
                currentUser: widget.currentUser,
                selectedUsers: _selectedTaggedUsers,
                onChanged: (users) {
                  setState(() => _selectedTaggedUsers = users);
                },
                title: 'Etiquetar personas',
                subtitle: 'Agregá fans reales que aparecen en este Drop.',
                compact: true,
              ),
              const SizedBox(height: 12),
              ArtistTagSelector(
                artistTagService: widget.artistTagService,
                selectedEntities: _selectedTaggedEntities,
                onChanged: (entities) {
                  setState(() => _selectedTaggedEntities = entities);
                },
                title: 'Etiquetar artista, grupo o idol',
                subtitle: 'Conectá este Drop con BTS, Jungkook, NewJeans...',
                compact: true,
              ),
              const SizedBox(height: 12),
              ProfileCategorySelector(
                selected: _selectedProfileCategories,
                onChanged: (categories) {
                  setState(() => _selectedProfileCategories = categories);
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('drop-publish'),
                onPressed: _processingVideo || _resolvingPrimaryEntity
                    ? null
                    : _publish,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _resolvingPrimaryEntity
                      ? 'Conectando artista...'
                      : 'Publicar Drop',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropUploadStatusCard extends StatelessWidget {
  const _DropUploadStatusCard({
    required this.processing,
    required this.optimized,
    required this.message,
  });

  final bool processing;
  final bool optimized;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = optimized ? AppTheme.rose : AppTheme.cyan;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                optimized ? Icons.content_cut_rounded : Icons.speed_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  processing ? 'Optimizando video' : 'Control de video',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (processing) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              minHeight: 4,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.3,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropUploadPlaceholder extends StatelessWidget {
  const _DropUploadPlaceholder({
    required this.onGallery,
    required this.onCamera,
  });

  final VoidCallback? onGallery;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.rose.withValues(alpha: 0.36),
            AppTheme.violet.withValues(alpha: 0.26),
            AppTheme.night,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 54),
          const SizedBox(height: 10),
          const Text(
            'Elegí o grabá un video',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: onGallery,
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Galería'),
              ),
              FilledButton.tonalIcon(
                onPressed: onCamera,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Cámara'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropVideoPreview extends StatefulWidget {
  const _DropVideoPreview({required this.videoPath, required this.filter});

  final String videoPath;
  final String filter;

  @override
  State<_DropVideoPreview> createState() => _DropVideoPreviewState();
}

class _DropVideoPreviewState extends State<_DropVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant _DropVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller?.dispose();
      _ready = false;
      _setup();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _setup() {
    final controller = VideoPlayerController.networkUrl(
      _videoUri(widget.videoPath),
    );
    _controller = controller;
    unawaited(
      controller.initialize().then((_) async {
        if (!mounted) return;
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.play();
        if (mounted) setState(() => _ready = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null) {
      return Container(
        color: AppTheme.night,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.rose),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        _DropFilterOverlay(filter: widget.filter),
      ],
    );
  }
}

class _DropUploadResult {
  const _DropUploadResult({
    required this.videoPath,
    this.videoBytes,
    this.videoFileName = '',
    this.videoMimeType = '',
    required this.caption,
    required this.artistName,
    required this.artistId,
    required this.groupId,
    required this.location,
    required this.filter,
    required this.audio,
    this.videoDurationSeconds,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.optimizedForUpload = false,
    this.profileCategories = const [],
    this.taggedUsers = const [],
    this.taggedEntities = const [],
  });

  final String videoPath;
  final Uint8List? videoBytes;
  final String videoFileName;
  final String videoMimeType;
  final String caption;
  final String artistName;
  final String artistId;
  final String groupId;
  final String location;
  final String filter;
  final String audio;
  final double? videoDurationSeconds;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool optimizedForUpload;
  final List<ProfileContentCategory> profileCategories;
  final List<CommunityProfile> taggedUsers;
  final List<KpopEntity> taggedEntities;
}

class _DropAction extends StatelessWidget {
  const _DropAction({
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
    final showLabel = RegExp(r'^\d').hasMatch(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          IconButton(
            onPressed: onPressed,
            tooltip: tooltip,
            style: IconButton.styleFrom(
              fixedSize: const Size(42, 42),
              backgroundColor: active
                  ? AppTheme.violet.withValues(alpha: 0.86)
                  : Colors.black.withValues(alpha: 0.38),
              foregroundColor: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.92),
              side: BorderSide(
                color: active
                    ? AppTheme.violet.withValues(alpha: 0.76)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            icon: Icon(icon, size: 22),
          ),
          if (showLabel) ...[
            const SizedBox(height: 3),
            SizedBox(
              width: 48,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NeonTag extends StatelessWidget {
  const _NeonTag(this.label, {super.key, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.34)),
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
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'Abrir perfil de $label',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _DropFilterOverlay extends StatelessWidget {
  const _DropFilterOverlay({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final colors = switch (filter) {
      'Hallyu Glow' => [const Color(0x33EF4F7A), const Color(0x2239E6E6)],
      'Neon Stage' => [const Color(0x445C2DFF), const Color(0x2265E4FF)],
      'Soft Pastel' => [const Color(0x32FF8BC7), const Color(0x22B8F7FF)],
      'Concert Lights' => [const Color(0x35FFB703), const Color(0x2200A6A6)],
      'Black Pink' => [const Color(0x33200024), const Color(0x44EF4F7A)],
      'Purple Galaxy' => [const Color(0x44A855F7), const Color(0x22110B22)],
      _ => [Colors.transparent, Colors.transparent],
    };
    if (filter == 'Original') return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _DropAura extends StatelessWidget {
  const _DropAura();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -90,
            child: _AuraBlob(color: AppTheme.rose),
          ),
          Positioned(
            bottom: -90,
            left: -80,
            child: _AuraBlob(color: AppTheme.amber),
          ),
        ],
      ),
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 90),
        ],
      ),
    );
  }
}

Uri _videoUri(String path) {
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:') ||
      path.startsWith('data:')) {
    return Uri.parse(path);
  }
  if (kIsWeb) return Uri.parse(path);
  return Uri.file(path);
}
