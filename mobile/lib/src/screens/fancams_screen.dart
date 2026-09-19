import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/demo_data.dart';
import '../data/discover_data.dart';
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
import '../services/media_permission_service.dart';
import '../services/fancam_view_tracking.dart';
import '../services/store_profile_service.dart';
import '../services/video_audio_preference.dart';
import '../services/video_playback_coordinator.dart';
import '../theme/app_theme.dart';
import '../utils/kpop_entity_reference.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/contextual_permission_sheet.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/profile_category_chips.dart';
import '../widgets/artist_tag_selector.dart';
import '../widgets/premium_form_shell.dart';
import '../widgets/safety_report_sheet.dart';
import '../widgets/share_sheet.dart';
import '../widgets/user_tag_selector.dart';
import '../widgets/video_loading_backdrop.dart';
import 'kpop_entity_profile_screen.dart';
import 'public_profile_screen.dart';

class FancamsScreen extends StatefulWidget {
  const FancamsScreen({
    super.key,
    this.user,
    this.artistId = '',
    this.groupId = '',
    this.title = 'Fancams',
    this.fancamService = const LocalFancamService(),
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.chatService = const LocalChatService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.resetSignal = 0,
    this.initialFancamId = '',
    this.showBackButton = false,
    this.isActive = true,
  });

  final AuthUser? user;
  final String artistId;
  final String groupId;
  final String title;
  final LocalFancamService fancamService;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalChatService chatService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;
  final int resetSignal;
  final String initialFancamId;
  final bool showBackButton;
  final bool isActive;

  @override
  State<FancamsScreen> createState() => _FancamsScreenState();
}

class _FancamsScreenState extends State<FancamsScreen> {
  final _pageController = PageController();
  final Map<String, List<PostComment>> _commentsByFancam = {};
  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Set<String> _loadedLiked = {};
  final Set<String> _loadedSaved = {};
  final Set<String> _busyFancamActions = {};
  final Map<String, int> _likeAdjustments = {};
  final Map<String, int> _commentAdditions = {};
  final Map<String, int> _commentRemovals = {};
  List<Fancam> _localFancams = [];
  final Set<String> _blockedUserIds = {};
  int _activeIndex = 0;
  bool _muted = true;
  bool _loadingFancams = true;
  bool _publishingFancam = false;
  String _appliedInitialFancamId = '';
  int _autoplaySignal = 0;

  @override
  void initState() {
    super.initState();
    LocalFancamService.revision.addListener(_restoreFancamState);
    LocalSafetyService.revision.addListener(_restoreFancamState);
    VideoAudioPreference.muted.addListener(_syncVideoAudioPreference);
    _muted = VideoAudioPreference.muted.value;
    if (widget.isActive) _autoplaySignal = 1;
    _restoreFancamState();
  }

  @override
  void dispose() {
    LocalFancamService.revision.removeListener(_restoreFancamState);
    LocalSafetyService.revision.removeListener(_restoreFancamState);
    VideoAudioPreference.muted.removeListener(_syncVideoAudioPreference);
    _pageController.dispose();
    super.dispose();
  }

  void _syncVideoAudioPreference() {
    if (!mounted) return;
    setState(() => _muted = VideoAudioPreference.muted.value);
  }

  @override
  void didUpdateWidget(covariant FancamsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) _resetToTop();
    if (oldWidget.initialFancamId != widget.initialFancamId) {
      _appliedInitialFancamId = '';
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

  void _scheduleInitialFancamJump(List<Fancam> visibleFancams) {
    final initialFancamId = widget.initialFancamId.trim();
    if (initialFancamId.isEmpty || _appliedInitialFancamId == initialFancamId) {
      return;
    }
    final index = visibleFancams.indexWhere(
      (fancam) => _fancamKey(fancam) == initialFancamId,
    );
    if (index < 0) return;
    _appliedInitialFancamId = initialFancamId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(index);
      if (_activeIndex != index) {
        setState(() => _activeIndex = index);
      }
    });
  }

  Future<void> _restoreFancamState() async {
    if (_localFancams.isEmpty && mounted) {
      setState(() => _loadingFancams = true);
    }
    try {
      final local = await widget.fancamService.restoreFancams();
      final liked = await widget.fancamService.restoreLikedFancamIds();
      final saved = await widget.fancamService.restoreSavedFancamIds();
      final blocked = await widget.safetyService.restoreBlockedUserIds();
      if (!mounted) return;
      setState(() {
        _localFancams = local;
        _blockedUserIds
          ..clear()
          ..addAll(blocked);
        _liked
          ..clear()
          ..addAll(liked);
        _saved
          ..clear()
          ..addAll(saved);
        _loadedLiked
          ..clear()
          ..addAll(liked);
        _loadedSaved
          ..clear()
          ..addAll(saved);
        _likeAdjustments.clear();
        _commentAdditions.clear();
        _commentRemovals.clear();
        _loadingFancams = false;
      });
    } catch (error) {
      debugPrint('FANCAM_FEED_ERROR restore error=$error');
      if (!mounted) return;
      setState(() => _loadingFancams = false);
    }
  }

  List<Fancam> get _visibleFancams {
    final items = widget.fancamService.usesRealFancams
        ? _localFancams
        : [..._localFancams, ...fancams];
    return items
        .where((fancam) {
          if (_blockedUserIds.contains(fancam.creatorId)) return false;
          if (widget.artistId.isNotEmpty) {
            return fancam.artistId == widget.artistId;
          }
          if (widget.groupId.isNotEmpty) {
            return fancam.groupId == widget.groupId;
          }
          return true;
        })
        .toList(growable: false);
  }

  String _fancamKey(Fancam fancam) {
    if (fancam.id.isNotEmpty) return fancam.id;
    return '${fancam.creatorId}-${fancam.artistId}-${fancam.title}';
  }

  CommunityProfile _creatorFor(Fancam fancam) {
    if (widget.fancamService.usesRealFancams ||
        fancam.creatorAvatarAsset.isNotEmpty) {
      return CommunityProfile(
        id: fancam.creatorId,
        name: fancam.creatorName.isEmpty ? 'Tu perfil' : fancam.creatorName,
        username: fancam.creator,
        city: fancam.location.isEmpty
            ? 'Ubicación no configurada'
            : fancam.location,
        country: '',
        fandom: fancam.artist,
        favoriteGroup: fancam.artist,
        bio: 'Creador/a de fancams en HallyuHub.',
        avatarAsset: fancam.creatorAvatarAsset.isEmpty
            ? 'assets/demo-users/user-01.jpg'
            : fancam.creatorAvatarAsset,
        followers: '0',
        posts: '1',
        colors: const [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
        online: true,
      );
    }
    return demoProfileById(fancam.creatorId);
  }

  AuthUser get _fallbackAuthor => const AuthUser(
    name: 'Tu perfil',
    email: 'demo@hallyuhub.local',
    username: '@tu.hallyu',
    country: '',
    fandom: 'ARMY',
    favoriteGroup: 'BTS',
    bio: 'Compartiendo fancams en HallyuHub.',
    avatarAsset: 'assets/demo-users/user-01.jpg',
  );

  AuthUser get _fancamAuthor => widget.user ?? _fallbackAuthor;

  void _openCreatorProfile(Fancam fancam) {
    final creator = _creatorFor(fancam);
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

  Future<void> _reportFancam(Fancam fancam) async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      title: 'Reportar Fancam: ${fancam.title}',
      contentType: 'fancam',
      contentId: _fancamKey(fancam),
      reportedUserId: fancam.creatorId,
      metadata: {
        'caption': fancam.caption,
        'creator': fancam.creator,
        'artist': fancam.artist,
        'audio': fancam.audio,
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

  Future<void> _openTaggedArtist(Fancam fancam) async {
    final entity = await resolveKpopEntityReference(
      artistTagService: widget.artistTagService,
      id: fancam.artistId,
      name: fancam.artist,
      knownEntities: fancam.taggedEntities,
    );
    if (!mounted) return;
    if (entity == null) {
      _showSnack('No pudimos encontrar el perfil de ${fancam.artist}.');
      return;
    }
    _openKpopEntity(entity);
  }

  Future<void> _toggleLike(Fancam fancam) async {
    final key = _fancamKey(fancam);
    if (_busyFancamActions.contains('like-$key')) return;
    final wasLiked = _liked.contains(key);
    final nextLiked = !wasLiked;
    setState(() {
      _busyFancamActions.add('like-$key');
      if (nextLiked) {
        _liked.add(key);
      } else {
        _liked.remove(key);
      }
      _likeAdjustments[key] =
          (nextLiked ? 1 : 0) - (_loadedLiked.contains(key) ? 1 : 0);
    });
    try {
      await widget.fancamService.setFancamLiked(key, nextLiked);
      if (!mounted) return;
      await _restoreFancamState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _liked.add(key);
        } else {
          _liked.remove(key);
        }
        _likeAdjustments.remove(key);
      });
      _showSnack(_fancamError(error));
    } finally {
      if (mounted) {
        setState(() => _busyFancamActions.remove('like-$key'));
      }
    }
  }

  Future<void> _toggleSaved(Fancam fancam) async {
    final key = _fancamKey(fancam);
    if (_busyFancamActions.contains('save-$key')) return;
    final wasSaved = _saved.contains(key);
    final nextSaved = !wasSaved;
    setState(() {
      _busyFancamActions.add('save-$key');
      if (nextSaved) {
        _saved.add(key);
      } else {
        _saved.remove(key);
      }
    });
    try {
      await widget.fancamService.setFancamSaved(key, nextSaved);
      if (!mounted) return;
      _showSnack(nextSaved ? 'Fancam guardada' : 'Guardado quitado');
      await _restoreFancamState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _saved.add(key);
        } else {
          _saved.remove(key);
        }
      });
      _showSnack(_fancamError(error));
    } finally {
      if (mounted) {
        setState(() => _busyFancamActions.remove('save-$key'));
      }
    }
  }

  Future<void> _openComments(Fancam fancam) async {
    final key = _fancamKey(fancam);
    var initialComments = _commentsByFancam[key];
    if (initialComments == null) {
      try {
        initialComments = await widget.fancamService.restoreComments(key);
      } catch (error) {
        if (!mounted) return;
        _showSnack(_fancamError(error));
        return;
      }
      if (!mounted) return;
      _commentsByFancam[key] = initialComments;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        threadId: 'fancam-$key',
        subtitle: fancam.title,
        initialComments: initialComments!,
        currentUserName: _fancamAuthor.name,
        currentUsername: _fancamAuthor.username,
        currentUserAvatar: _fancamAuthor.avatarAsset,
        safetyService: widget.safetyService,
        reportContentType: 'fancam_comment',
        onSubmitComment: (body, parentId) => widget.fancamService.addComment(
          author: _fancamAuthor,
          fancamId: key,
          body: body,
          parentId: parentId,
        ),
        onDeleteComment: (comment) => widget.fancamService.deleteComment(
          fancamId: key,
          commentId: comment.id,
        ),
        onOpenAuthor: _openCommentAuthor,
        onChanged: (comments) =>
            setState(() => _commentsByFancam[key] = comments),
        onCommentAdded: () {
          setState(() {
            _commentAdditions.update(
              key,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          });
          _showSnack('Comentario agregado');
        },
        onCommentsRemoved: (count) {
          setState(() {
            _commentRemovals.update(
              key,
              (value) => value + count,
              ifAbsent: () => count,
            );
          });
        },
      ),
    );
  }

  void _openShare(Fancam fancam) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppShareSheet(
        title: 'Compartir fancam',
        subtitle: fancam.title,
        shareText:
            'Mirá esta fancam de ${fancam.artist} en HallyuHub: ${fancam.title}',
        recipients: _shareRecipients,
        onSelected: _showSnack,
      ),
    );
  }

  List<ShareRecipient> get _shareRecipients {
    if (widget.followService.usesRealProfiles) return const [];
    return demoProfiles
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
  }

  Future<void> _openUploadFlow() async {
    if (_publishingFancam) return;
    final result = await showModalBottomSheet<_FancamUploadResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FancamUploadSheet(
        currentUser: widget.user,
        followService: widget.followService,
        artistTagService: widget.artistTagService,
      ),
    );
    if (result == null) return;
    setState(() => _publishingFancam = true);
    Fancam publishedFancam;
    try {
      publishedFancam = await widget.fancamService.publish(
        author: _fancamAuthor,
        videoPath: result.videoPath,
        videoBytes: result.videoBytes,
        videoFileName: result.videoFileName,
        videoMimeType: result.videoMimeType,
        caption: result.caption,
        artist: result.artistName,
        groupId: result.groupId,
        artistId: result.artistId,
        location: result.location,
        videoDurationSeconds: result.videoDurationSeconds,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _publishingFancam = false);
      _showSnack(_fancamError(error));
      return;
    }
    final categoriesSaved = await _saveProfileCategories(
      userId: publishedFancam.creatorId,
      contentType: ProfileContentType.fancam,
      contentId: _fancamKey(publishedFancam),
      categories: result.profileCategories,
    );
    await _saveUserTags(
      contentType: ProfileContentType.fancam,
      contentId: _fancamKey(publishedFancam),
      taggedUsers: result.taggedUsers,
    );
    await _saveArtistTags(
      contentType: ProfileContentType.fancam,
      contentId: _fancamKey(publishedFancam),
      taggedEntities: result.taggedEntities,
    );
    await _restoreFancamState();
    if (!mounted) return;
    setState(() => _publishingFancam = false);
    if (categoriesSaved) _showSnack('Fancam publicada');
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 260),
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
      debugPrint('PROFILE_CATEGORY_SAVE_ERROR fancam error=$error');
      if (!mounted) return false;
      _showSnack('Fancam publicada. No pudimos guardarla en los globitos.');
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
        'CONTENT_USER_TAGS_SAVE_ERROR fancams $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack('Fancam publicada, pero no pudimos guardar las etiquetas.');
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
        'CONTENT_ARTIST_TAGS_SAVE_ERROR fancams $contentType/$contentId $error',
      );
      if (!mounted) return;
      _showSnack(
        'Fancam publicada, pero no pudimos guardar artistas etiquetados.',
      );
    }
  }

  Future<void> _deleteFancam(Fancam fancam) async {
    if (!fancam.isOwn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Eliminar Fancam',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Se va a quitar esta Fancam de tu feed. Esta acción no se puede deshacer.',
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
      await widget.fancamService.deleteFancam(_fancamKey(fancam));
      await _restoreFancamState();
      if (!mounted) return;
      _showSnack('Fancam eliminada');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_fancamError(error));
    }
  }

  String _fancamLikeLabel(Fancam fancam) {
    final key = _fancamKey(fancam);
    final base = int.tryParse(fancam.likes) ?? 0;
    final value = (base + (_likeAdjustments[key] ?? 0)).clamp(0, 999999);
    return '$value';
  }

  String _fancamCommentLabel(Fancam fancam) {
    final key = _fancamKey(fancam);
    final base = int.tryParse(fancam.comments) ?? 0;
    final value =
        (base + (_commentAdditions[key] ?? 0) - (_commentRemovals[key] ?? 0))
            .clamp(0, 999999);
    return '$value';
  }

  String _fancamError(Object error) {
    if (error is FancamServiceException && error.message.isNotEmpty) {
      return error.message;
    }
    _log('FANCAM_UPLOAD_ERROR', {'step': 'ui_unhandled', 'error': '$error'});
    return 'No pudimos completar la acción en Fancams. Probá de nuevo en unos segundos.';
  }

  void _recordView(Fancam fancam, String playbackSessionId) {
    if (!widget.fancamService.usesRealFancams || fancam.id.isEmpty) return;
    unawaited(
      widget.fancamService
          .recordView(fancamId: fancam.id, playbackSessionId: playbackSessionId)
          .catchError((error) {
            debugPrint('FANCAM_VIEW_ERROR id=${fancam.id} error=$error');
          }),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _log(String event, Map<String, Object?> data) {
    debugPrint(
      '$event ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleFancams = _visibleFancams;
    _scheduleInitialFancamJump(visibleFancams);
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            const _FancamAura(),
            if (_loadingFancams && visibleFancams.isEmpty)
              const _FancamLoadingState()
            else if (visibleFancams.isEmpty)
              _EmptyFancamFeed(title: widget.title, onCreate: _openUploadFlow)
            else
              PageView.builder(
                key: const ValueKey('fancams-reels-feed'),
                controller: _pageController,
                scrollDirection: Axis.vertical,
                pageSnapping: true,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemCount: visibleFancams.length,
                itemBuilder: (context, index) {
                  final fancam = visibleFancams[index];
                  final key = _fancamKey(fancam);
                  return _FancamReelCard(
                    key: ValueKey('fancam-reel-$key'),
                    fancam: fancam,
                    creator: _creatorFor(fancam),
                    title: widget.title,
                    muted: _muted,
                    liked: _liked.contains(key),
                    saved: _saved.contains(key),
                    selected: index == _activeIndex,
                    screenActive: widget.isActive,
                    autoplaySignal: _autoplaySignal,
                    likesCount: _fancamLikeLabel(fancam),
                    commentsCount: _fancamCommentLabel(fancam),
                    onToggleSound: () => VideoAudioPreference.setMuted(
                      !_muted,
                      source: 'fancams',
                    ),
                    onLike: () => _toggleLike(fancam),
                    onSave: () => _toggleSaved(fancam),
                    onComment: () => _openComments(fancam),
                    onShare: () => _openShare(fancam),
                    onReport: () => _reportFancam(fancam),
                    onDelete: fancam.isOwn ? () => _deleteFancam(fancam) : null,
                    onCreator: () => _openCreatorProfile(fancam),
                    onArtist: () => _openTaggedArtist(fancam),
                    onOpenTaggedPerson: _openTaggedUsername,
                    onOpenTaggedEntity: _openKpopEntity,
                    onFollow: () =>
                        _showSnack('Ahora seguís a ${fancam.creator}'),
                    onView: (sessionId) => _recordView(fancam, sessionId),
                  );
                },
              ),
            if (widget.showBackButton)
              Positioned(
                left: 18,
                top: 18,
                child: FloatingActionButton.small(
                  heroTag: 'fancams-profile-back-button',
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
                  featureId: 'fancams_intro',
                  title: 'Fancams de tus artistas 🎤',
                  message:
                      'Compartí y descubrí videos de performances y momentos de tus artistas.',
                  mascotAsset: 'assets/brand/hally_mascot_wave_transparent.png',
                  compact: true,
                ),
              ),
            if (!widget.showBackButton)
              Positioned(
                right: 18,
                top: 18,
                child: FloatingActionButton.small(
                  key: const ValueKey('fancam-upload-plus'),
                  heroTag: 'fancam-upload-plus',
                  onPressed: _publishingFancam ? null : _openUploadFlow,
                  tooltip: 'Subir fancam',
                  backgroundColor: AppTheme.rose,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            if (_publishingFancam)
              Container(
                color: AppTheme.night.withValues(alpha: 0.74),
                child: const Center(child: _FancamPublishingStatus()),
              ),
          ],
        ),
      ),
    );
  }
}

class _FancamReelCard extends StatelessWidget {
  const _FancamReelCard({
    super.key,
    required this.fancam,
    required this.creator,
    required this.title,
    required this.muted,
    required this.liked,
    required this.saved,
    required this.selected,
    required this.screenActive,
    required this.autoplaySignal,
    required this.likesCount,
    required this.commentsCount,
    required this.onToggleSound,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    required this.onReport,
    required this.onDelete,
    required this.onCreator,
    required this.onArtist,
    required this.onOpenTaggedPerson,
    required this.onOpenTaggedEntity,
    required this.onFollow,
    required this.onView,
  });

  final Fancam fancam;
  final CommunityProfile creator;
  final String title;
  final bool muted;
  final bool liked;
  final bool saved;
  final bool selected;
  final bool screenActive;
  final int autoplaySignal;
  final String likesCount;
  final String commentsCount;
  final VoidCallback onToggleSound;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback? onDelete;
  final VoidCallback onCreator;
  final VoidCallback onArtist;
  final ValueChanged<String> onOpenTaggedPerson;
  final ValueChanged<KpopEntity> onOpenTaggedEntity;
  final VoidCallback onFollow;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    final caption = fancam.caption.isEmpty ? fancam.title : fancam.caption;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FancamMedia(
              fancam: fancam,
              muted: muted,
              selected: selected,
              screenActive: screenActive,
              autoplaySignal: autoplaySignal,
              onView: onView,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 68,
              top: 14,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GlassPill(
                    icon: Icons.play_circle_outline_rounded,
                    label: title,
                  ),
                  _GlassPill(
                    icon: Icons.schedule_rounded,
                    label: fancam.duration,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _FancamActionRail(
                  liked: liked,
                  saved: saved,
                  likes: likesCount,
                  comments: commentsCount,
                  onLike: onLike,
                  onComment: onComment,
                  onSave: onSave,
                  onShare: onShare,
                  onReport: fancam.isOwn ? null : onReport,
                  onDelete: onDelete,
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
                    behavior: HitTestBehavior.opaque,
                    onTap: onCreator,
                    child: Row(
                      children: [
                        HubAvatar(
                          asset: creator.avatarAsset,
                          size: 38,
                          isLive: creator.online || fancam.isOwn,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                fancam.creator,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: onFollow,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.14,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Seguir'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  GestureDetector(
                    onTap: onArtist,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _NeonTag(fancam.artist),
                        if (fancam.energy.isNotEmpty) _NeonTag(fancam.energy),
                        if (fancam.location.isNotEmpty)
                          _NeonTag(fancam.location),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.25,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (fancam.taggedPeople.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TaggedVideoPeopleRow(
                      usernames: fancam.taggedPeople,
                      onOpen: onOpenTaggedPerson,
                    ),
                  ],
                  if (fancam.taggedEntities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TaggedVideoEntityRow(
                      entities: fancam.taggedEntities,
                      onOpen: onOpenTaggedEntity,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FancamSoundPill(
                        key: ValueKey('fancam-sound-${fancam.id}'),
                        muted: muted,
                        onPressed: onToggleSound,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fancam.audio.isEmpty
                              ? 'Audio original'
                              : fancam.audio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
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

class _FancamMedia extends StatefulWidget {
  const _FancamMedia({
    required this.fancam,
    required this.muted,
    required this.selected,
    required this.screenActive,
    required this.autoplaySignal,
    required this.onView,
  });

  final Fancam fancam;
  final bool muted;
  final bool selected;
  final bool screenActive;
  final int autoplaySignal;
  final ValueChanged<String> onView;

  @override
  State<_FancamMedia> createState() => _FancamMediaState();
}

class _FancamMediaState extends State<_FancamMedia> {
  final Object _playbackOwner = Object();
  VideoPlayerController? _controller;
  Timer? _audioNoticeTimer;
  String _audioNotice = '';
  bool _playing = false;
  bool _ready = false;
  bool _videoError = false;
  String _playbackSessionId = '';
  late final FancamViewSessionTracker _viewTracker;

  @override
  void initState() {
    super.initState();
    _viewTracker = FancamViewSessionTracker();
    _setupVideo();
  }

  @override
  void didUpdateWidget(covariant _FancamMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fancam.videoPath != widget.fancam.videoPath) {
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
    if (!widget.fancam.hasVideo) return;
    _logAudio('VIDEO_AUDIO_INIT', {
      'muted': widget.muted,
      'active': widget.screenActive && widget.selected,
    });
    _videoError = false;
    final controller = VideoPlayerController.networkUrl(
      _videoUri(widget.fancam.videoPath),
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
      source: 'fancams',
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
      _playbackSessionId = newFancamPlaybackSessionId();
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
    final id = widget.fancam.id.isEmpty
        ? widget.fancam.title
        : widget.fancam.id;
    debugPrint(
      '$event source=fancams id=$id ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
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
            ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else if (controller != null && !_videoError)
            const VideoLoadingBackdrop(label: '')
          else if (_videoError)
            const VideoErrorBackdrop()
          else
            ColoredBox(
              color: Colors.black,
              child: Image.asset(widget.fancam.imageAsset, fit: BoxFit.contain),
            ),
          if (controller == null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          if (controller != null && _ready && !_playing)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 64,
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
              child: _FancamInlineNotice(message: _audioNotice),
            ),
        ],
      ),
    );
  }
}

class _FancamSoundPill extends StatelessWidget {
  const _FancamSoundPill({
    super.key,
    required this.muted,
    required this.onPressed,
  });

  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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

class _FancamInlineNotice extends StatelessWidget {
  const _FancamInlineNotice({required this.message});

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

class _FancamActionRail extends StatelessWidget {
  const _FancamActionRail({
    required this.liked,
    required this.saved,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onReport,
    required this.onDelete,
  });

  final bool liked;
  final bool saved;
  final String likes;
  final String comments;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FancamActionButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: likes,
          active: liked,
          onTap: onLike,
        ),
        _FancamActionButton(
          icon: Icons.mode_comment_outlined,
          label: comments,
          onTap: onComment,
        ),
        _FancamActionButton(
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: saved ? 'Guardado' : 'Guardar',
          active: saved,
          onTap: onSave,
        ),
        _FancamActionButton(
          icon: Icons.ios_share_rounded,
          label: 'Compartir',
          onTap: onShare,
        ),
        if (onReport != null)
          _FancamActionButton(
            icon: Icons.flag_outlined,
            label: 'Reportar',
            onTap: onReport!,
          ),
        if (onDelete != null)
          _FancamActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Borrar',
            onTap: onDelete!,
          ),
      ],
    );
  }
}

class _FancamActionButton extends StatelessWidget {
  const _FancamActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final showLabel = RegExp(r'^\d').hasMatch(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkResponse(
              onTap: onTap,
              radius: 28,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppTheme.violet.withValues(alpha: 0.86)
                      : Colors.black.withValues(alpha: 0.38),
                  border: Border.all(
                    color: active
                        ? AppTheme.violet.withValues(alpha: 0.76)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FancamUploadSheet extends StatefulWidget {
  const _FancamUploadSheet({
    required this.currentUser,
    required this.followService,
    required this.artistTagService,
  });

  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalArtistTagService artistTagService;

  @override
  State<_FancamUploadSheet> createState() => _FancamUploadSheetState();
}

class _FancamUploadSheetState extends State<_FancamUploadSheet> {
  static const _maxFancamDuration = Duration(minutes: 5);
  final _picker = ImagePicker();
  final _permissionService = const MediaPermissionService();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController(text: 'Santiago');
  String _videoPath = '';
  Uint8List? _videoBytes;
  String _videoFileName = '';
  String _videoMimeType = '';
  String _selectedArtistId = discoverIdols.first.id;
  Duration? _videoDuration;
  bool _processingVideo = false;
  bool _resolvingPrimaryEntity = false;
  Set<ProfileContentCategory> _selectedProfileCategories = {};
  List<CommunityProfile> _selectedTaggedUsers = const [];
  List<KpopEntity> _selectedTaggedEntities = const [];
  String _videoNotice =
      'Fancams acepta videos de hasta 5 minutos y 100 MB durante el acceso anticipado.';

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
      title: source == ImageSource.camera
          ? 'Grabar fancam'
          : 'Elegir video de galería',
      detail: source == ImageSource.camera
          ? 'HallyuHub necesita cámara y micrófono para grabar un video.'
          : 'HallyuHub necesita acceso a tus videos para subir una fancam.',
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
      maxDuration: _maxFancamDuration,
    );
    if (picked == null || !mounted) return;
    _log('FANCAM_PICKED_FILE', {
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
      _processingVideo = true;
      _videoNotice = 'Preparando video para subirlo como Fancam...';
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
    if (bytes.lengthInBytes > LocalFancamService.maxVideoBytes) {
      _log('FANCAM_UPLOAD_ERROR', {
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
    _log('FANCAM_VIDEO_BYTES_READY', {
      'bytes': bytes.lengthInBytes,
      'fileName': picked.name,
      'mimeType': picked.mimeType ?? '',
    });
    final duration = await _readVideoDuration(picked.path);
    if (!mounted) return;
    setState(() {
      _videoBytes = bytes;
      _videoDuration = duration;
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
    if (duration > _maxFancamDuration) {
      return 'El video dura $formatted. Durante el acceso anticipado recortalo a 5 minutos o elegí un clip más corto.';
    }
    return 'Video listo: $formatted. Se subirá como Fancam vertical.';
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
    _log('FANCAM_UPLOAD_ERROR', {
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
    if (_videoDuration != null && _videoDuration! > _maxFancamDuration) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('La Fancam no puede superar 5 minutos por ahora.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final idol = _selectedIdol;
    setState(() => _resolvingPrimaryEntity = true);
    final primaryEntity = await resolveKpopEntityReference(
      artistTagService: widget.artistTagService,
      id: idol.id,
      name: idol.name,
      aliases: <String>[idol.realName, idol.fullName, ...idol.aliases],
      knownEntities: _selectedTaggedEntities,
      allowLocalFallback: false,
    );
    if (!mounted) return;
    if (primaryEntity == null) {
      setState(() => _resolvingPrimaryEntity = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No encontramos el perfil real de ${idol.name}. Elegilo en Etiquetar artista e intentá de nuevo.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final taggedEntities = <String, KpopEntity>{
      primaryEntity.id: primaryEntity,
      for (final entity in _selectedTaggedEntities) entity.id: entity,
    }.values.toList(growable: false);
    Navigator.of(context).pop(
      _FancamUploadResult(
        videoPath: _videoPath,
        videoBytes: _videoBytes,
        videoFileName: _videoFileName,
        videoMimeType: _videoMimeType,
        caption: _captionController.text.trim(),
        artistName: primaryEntity.name,
        artistId: primaryEntity.id,
        groupId: idol.groupId,
        location: _locationController.text.trim(),
        videoDurationSeconds: _videoDuration == null
            ? null
            : _videoDuration!.inMilliseconds / 1000,
        profileCategories: _selectedProfileCategories.toList(growable: false),
        taggedUsers: _selectedTaggedUsers,
        taggedEntities: taggedEntities,
      ),
    );
  }

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
                title: 'Subir fancam',
                subtitle:
                    'Prepará el video, conectalo con el artista y revisalo antes de publicar.',
                icon: Icons.videocam_rounded,
                visual: PremiumFormVisual.create,
                trailing: IconButton(
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
                          ? _UploadPlaceholder(
                              onGallery: _processingVideo
                                  ? null
                                  : () => _pickVideo(ImageSource.gallery),
                              onCamera: _processingVideo
                                  ? null
                                  : () => _pickVideo(ImageSource.camera),
                            )
                          : _FancamVideoPreview(videoPath: _videoPath),
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
                      key: const ValueKey('fancam-pick-gallery'),
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
                      key: const ValueKey('fancam-pick-camera'),
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
              _FancamUploadStatusCard(
                processing: _processingVideo,
                tooLong:
                    _videoDuration != null &&
                    _videoDuration! > _maxFancamDuration,
                message: _videoNotice,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('fancam-caption'),
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: dance focus desde el meetup de hoy...',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('fancam-artist'),
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
              TextField(
                key: const ValueKey('fancam-location'),
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
                subtitle: 'Agregá fans reales que aparecen en esta Fancam.',
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
                subtitle: 'Conectá esta Fancam con BTS, Lisa, Stray Kids...',
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
                key: const ValueKey('fancam-publish'),
                onPressed: _processingVideo || _resolvingPrimaryEntity
                    ? null
                    : _publish,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _resolvingPrimaryEntity
                      ? 'Conectando perfil...'
                      : 'Publicar fancam',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  const _UploadPlaceholder({required this.onGallery, required this.onCamera});

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
            AppTheme.rose.withValues(alpha: 0.38),
            AppTheme.violet.withValues(alpha: 0.24),
            AppTheme.night,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.movie_creation_outlined,
            color: Colors.white,
            size: 54,
          ),
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

class _FancamUploadStatusCard extends StatelessWidget {
  const _FancamUploadStatusCard({
    required this.processing,
    required this.tooLong,
    required this.message,
  });

  final bool processing;
  final bool tooLong;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = tooLong ? AppTheme.rose : AppTheme.cyan;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tooLong ? Icons.content_cut_rounded : Icons.speed_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  processing ? 'Preparando video' : 'Control de video',
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

class _FancamVideoPreview extends StatefulWidget {
  const _FancamVideoPreview({required this.videoPath});

  final String videoPath;

  @override
  State<_FancamVideoPreview> createState() => _FancamVideoPreviewState();
}

class _FancamVideoPreviewState extends State<_FancamVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant _FancamVideoPreview oldWidget) {
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
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _FancamUploadResult {
  const _FancamUploadResult({
    required this.videoPath,
    this.videoBytes,
    this.videoFileName = '',
    this.videoMimeType = '',
    required this.caption,
    required this.artistName,
    required this.artistId,
    required this.groupId,
    required this.location,
    this.videoDurationSeconds,
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
  final double? videoDurationSeconds;
  final List<ProfileContentCategory> profileCategories;
  final List<CommunityProfile> taggedUsers;
  final List<KpopEntity> taggedEntities;
}

class _EmptyFancamFeed extends StatelessWidget {
  const _EmptyFancamFeed({required this.title, required this.onCreate});

  final String title;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: AppTheme.cyan,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title == 'Fancams'
                    ? 'Todavía no hay Fancams por acá. Cuando subas una performance, va a aparecer en este feed.'
                    : 'Todavía no hay fancams etiquetadas para este artista. Cuando alguien suba una, va a aparecer acá.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Subir Fancam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FancamLoadingState extends StatelessWidget {
  const _FancamLoadingState();

  @override
  Widget build(BuildContext context) {
    return const VideoLoadingBackdrop(label: '');
  }
}

class _FancamPublishingStatus extends StatelessWidget {
  const _FancamPublishingStatus();

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
            'Subiendo Fancam...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonTag extends StatelessWidget {
  const _NeonTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}

class _FancamAura extends StatelessWidget {
  const _FancamAura();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -90,
            child: _AuraBlob(color: AppTheme.rose),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _AuraBlob(color: AppTheme.cyan),
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
