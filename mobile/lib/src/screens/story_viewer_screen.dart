import 'dart:async';

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models.dart';
import '../screens/story_profile_screen.dart';
import '../services/local_chat_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_story_service.dart';
import '../services/share_links.dart';
import '../services/story_audio_controller.dart';
import '../services/story_time.dart';
import '../theme/app_theme.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/share_sheet.dart';
import '../widgets/story_canvas.dart';
import '../widgets/story_stats_sheet.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.recipients,
    required this.starredStoryIds,
    required this.onViewed,
    required this.onToggleStar,
    required this.onReply,
    this.onDelete,
    this.currentUser,
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.chatService = const LocalChatService(),
  });

  final List<Story> stories;
  final int initialIndex;
  final List<ShareRecipient> recipients;
  final Set<String> starredStoryIds;
  final ValueChanged<Story> onViewed;
  final ValueChanged<Story> onToggleStar;
  final void Function(Story story, String message) onReply;
  final Future<void> Function(Story story)? onDelete;
  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalChatService chatService;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  final _replyController = TextEditingController();
  final _audio = StoryAudioController();
  late final AnimationController _progressController;
  late int _index;
  bool _paused = false;
  bool _videoMuted = false;
  bool _replySending = false;

  Story get _story => widget.stories[_index];

  List<Story> get _activeGroup => widget.stories
      .where((story) => story.authorId == _story.authorId)
      .toList();

  int get _activeGroupIndex =>
      _activeGroup.indexWhere((story) => story.id == _story.id);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progressController =
        AnimationController(vsync: this, duration: _durationFor(_story))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _next();
          });
    _activateCurrentStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _audio.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _activateCurrentStory() {
    final story = _story;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onViewed(story);
    });
    _replyController.clear();
    _paused = false;
    _videoMuted = story.videoMuted;
    _progressController
      ..stop()
      ..duration = _durationFor(story)
      ..value = 0
      ..forward();
    unawaited(_audio.play(story.musicAsset));
  }

  Duration _durationFor(Story story) {
    final selectedVideoDuration =
        (story.videoTrimEndSeconds ?? story.durationSeconds.toDouble()) -
        story.videoTrimStartSeconds;
    return Duration(
      seconds: story.contentType == StoryContentType.video
          ? selectedVideoDuration.ceil().clamp(1, 60)
          : story.durationSeconds.clamp(1, 30),
    );
  }

  void _showAt(int index) {
    if (index < 0) return;
    if (index >= widget.stories.length) {
      _close();
      return;
    }
    setState(() => _index = index);
    _activateCurrentStory();
  }

  void _next() {
    if (_index + 1 >= widget.stories.length) {
      _close();
      return;
    }
    _showAt(_index + 1);
  }

  void _previous() {
    if (_index == 0) {
      _resume();
      return;
    }
    _showAt(_index - 1);
  }

  void _handleTap(TapUpDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx < width * 0.42) {
      _previous();
    } else {
      _next();
    }
  }

  void _pause() {
    if (_paused) return;
    setState(() => _paused = true);
    _progressController.stop();
    unawaited(_audio.pause());
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _progressController.forward();
    unawaited(_audio.resume());
  }

  void _toggleStar() {
    widget.onToggleStar(_story);
    setState(() {});
    _resume();
  }

  Future<void> _sendReply() async {
    if (_replySending) return;
    final message = _replyController.text.trim();
    if (message.isEmpty) return;
    final story = _story;
    if (story.isOwn) {
      _showSnack('No podés responder tu propia historia por DM.');
      return;
    }
    if (_storyExpired(story)) {
      _showSnack('Esta historia ya expiró.');
      return;
    }
    if (message.length > LocalChatService.maxMessageLength) {
      _showSnack('El mensaje es demasiado largo.');
      return;
    }
    setState(() => _replySending = true);
    try {
      await widget.chatService.sendStoryReply(
        story: story,
        recipient: _replyRecipient(story),
        body: message,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyReplyError(error));
      setState(() => _replySending = false);
      _resume();
      return;
    }
    if (!mounted) return;
    var pending = false;
    if (widget.chatService.usesRealMessages) {
      try {
        pending = await widget.chatService.isMessageRequestPending(
          story.authorId,
        );
      } catch (_) {
        pending = false;
      }
    }
    if (!mounted) return;
    widget.onReply(story, message);
    _replyController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _replySending = false);
    if (widget.chatService.usesRealMessages) {
      _showSnack(
        pending
            ? 'Respuesta enviada como solicitud de mensaje.'
            : 'Respuesta enviada.',
      );
    } else {
      _showSnack('Respuesta enviada a ${story.name.split(' ').first}');
    }
    _resume();
  }

  CommunityProfile _replyRecipient(Story story) {
    if (!widget.chatService.usesRealMessages) {
      return demoProfileById(story.authorId);
    }
    return CommunityProfile(
      id: story.authorId,
      name: story.name,
      username: _usernameFor(story),
      city: '',
      country: '',
      fandom: story.fandom,
      favoriteGroup: '',
      bio: '',
      avatarAsset: story.avatarAsset,
      followers: '',
      posts: '',
      colors: const [],
    );
  }

  String _usernameFor(Story story) {
    final normalized = story.name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');
    return normalized.isEmpty ? '@hallyu.fan' : '@$normalized';
  }

  bool _storyExpired(Story story) {
    final createdAt = story.createdAt;
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt.toLocal()) >=
        const Duration(hours: 24);
  }

  String _friendlyReplyError(Object error) {
    final message = error.toString();
    if (message.startsWith('ChatServiceException: ')) {
      return message.replaceFirst('ChatServiceException: ', '');
    }
    return 'No pudimos enviar la respuesta. Probá otra vez.';
  }

  Future<void> _openProfile() async {
    _pause();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => StoryProfileScreen(
          story: _story,
          currentUser: widget.currentUser,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          chatService: widget.chatService,
        ),
      ),
    );
    if (mounted) _resume();
  }

  void _close() {
    _progressController.stop();
    unawaited(_audio.stop());
    Navigator.of(context).maybePop();
  }

  void _openStats() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StoryStatsSheet(story: _story),
    ).whenComplete(_resume);
  }

  void _openShare() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => AppShareSheet(
        title: 'Compartir historia',
        subtitle: '${_story.name} · ${_story.fandom}',
        shareText:
            'Mirá la historia de ${_story.name} en HallyuHub: '
            '${ShareLinks.story(_story.id)}',
        recipients: widget.recipients,
        onSelected: (label) {
          Navigator.of(sheetContext).pop();
          _showSnack(label);
        },
      ),
    ).whenComplete(_resume);
  }

  Future<void> _deleteOwnStory() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    _pause();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Eliminar historia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'La historia se va a quitar de Tu historia. Esta acción no se puede deshacer.',
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
    if (!mounted) return;
    if (confirmed != true) {
      _resume();
      return;
    }
    try {
      await onDelete(_story);
      if (mounted) _close();
    } catch (_) {
      if (mounted) _resume();
    }
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

  @override
  Widget build(BuildContext context) {
    final starred = widget.starredStoryIds.contains(_story.id);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _StoryMedia(story: _story, paused: _paused, videoMuted: _videoMuted),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xA6000000),
                  Color(0x10000000),
                  Color(0xC4000000),
                ],
              ),
            ),
          ),
          Positioned.fill(
            bottom: _story.isOwn ? 102 : 128,
            child: GestureDetector(
              key: const ValueKey('story-navigation-area'),
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) => _pause(),
              onTapCancel: _resume,
              onTapUp: _handleTap,
              onLongPressStart: (_) => _pause(),
              onLongPressEnd: (_) => _resume(),
              onLongPressUp: _resume,
              onHorizontalDragStart: (_) => _pause(),
              onHorizontalDragCancel: _resume,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -120) {
                  _next();
                } else if (velocity > 120) {
                  _previous();
                } else {
                  _resume();
                }
              },
              onVerticalDragStart: (_) => _pause(),
              onVerticalDragCancel: _resume,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 180) {
                  _close();
                } else {
                  _resume();
                }
              },
            ),
          ),
          if (_paused)
            const Center(
              child: Icon(
                Icons.pause_circle_filled_rounded,
                key: ValueKey('story-paused'),
                color: Colors.white70,
                size: 58,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  _StoryProgress(
                    stories: _activeGroup,
                    activeIndex: _activeGroupIndex,
                    progress: _progressController,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const ValueKey('story-open-profile'),
                          onTap: _openProfile,
                          borderRadius: BorderRadius.circular(14),
                          child: Row(
                            children: [
                              HubAvatar(
                                asset: _story.avatarAsset,
                                size: 42,
                                isLive: _story.isLive,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _story.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${_story.fandom} · ${storyRelativeTime(_story)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.68,
                                        ),
                                        fontSize: 12,
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
                      if (_story.contentType == StoryContentType.video)
                        IconButton(
                          key: const ValueKey('story-video-mute'),
                          onPressed: () =>
                              setState(() => _videoMuted = !_videoMuted),
                          icon: Icon(
                            _videoMuted
                                ? Icons.volume_off_outlined
                                : Icons.volume_up_outlined,
                          ),
                          color: Colors.white,
                          tooltip: _videoMuted
                              ? 'Activar sonido del video'
                              : 'Silenciar video',
                        ),
                      IconButton(
                        onPressed: _close,
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        tooltip: 'Cerrar historia',
                      ),
                    ],
                  ),
                  const Spacer(),
                  _StoryDetails(story: _story),
                  const SizedBox(height: 14),
                  if (_story.isOwn)
                    _OwnStoryFooter(
                      story: _story,
                      onStats: _openStats,
                      onShare: _openShare,
                      onDelete: widget.onDelete == null
                          ? null
                          : _deleteOwnStory,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('story-reply-input'),
                            controller: _replyController,
                            onTap: _pause,
                            onSubmitted: (_) => _sendReply(),
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(
                              hintText: 'Responder a ${_story.name}',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.64),
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.34),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.36),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.36),
                                ),
                              ),
                              suffixIcon: IconButton(
                                onPressed: _replySending ? null : _sendReply,
                                icon: _replySending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                                color: Colors.white,
                                tooltip: 'Enviar respuesta',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const ValueKey('story-star'),
                          onPressed: _toggleStar,
                          icon: Icon(starred ? Icons.star : Icons.star_border),
                          color: starred ? AppTheme.amber : Colors.white,
                          tooltip: starred ? 'Quitar estrella' : 'Dar estrella',
                        ),
                        IconButton(
                          key: const ValueKey('story-share'),
                          onPressed: _openShare,
                          icon: const Icon(Icons.share_outlined),
                          color: Colors.white,
                          tooltip: 'Compartir historia',
                        ),
                      ],
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

class _StoryProgress extends StatelessWidget {
  const _StoryProgress({
    required this.stories,
    required this.activeIndex,
    required this.progress,
  });

  final List<Story> stories;
  final int activeIndex;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stories.length, (index) {
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == stories.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: index == activeIndex
                ? AnimatedBuilder(
                    animation: progress,
                    builder: (context, child) => LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          key: const ValueKey('story-progress-active'),
                          width: constraints.maxWidth * progress.value,
                          height: constraints.maxHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(
                                  -1 + (progress.value * 0.32),
                                  0,
                                ),
                                end: Alignment(1 + (progress.value * 0.32), 0),
                                colors: const [
                                  Color(0xFFFF4F9A),
                                  AppTheme.cyan,
                                  AppTheme.violet,
                                  Color(0xFFFFA7D0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.cyan.withValues(alpha: 0.9),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : index < activeIndex
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
                      ),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }
}

class _StoryDetails extends StatelessWidget {
  const _StoryDetails({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    if (story.title.isEmpty &&
        story.detail.isEmpty &&
        story.music.isEmpty &&
        story.memoryLabel.isEmpty) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (story.memoryLabel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                story.memoryLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (story.title.isNotEmpty)
            Text(
              story.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (story.detail.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              story.detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (story.music.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.white, size: 17),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    story.music,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnStoryFooter extends StatelessWidget {
  const _OwnStoryFooter({
    required this.story,
    required this.onStats,
    required this.onShare,
    this.onDelete,
  });

  final Story story;
  final VoidCallback onStats;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('story-own-summary'),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              key: const ValueKey('story-own-stats'),
              onPressed: onStats,
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: Colors.white,
              ),
              child: Text('${story.views} vistas · ${story.stars} estrellas'),
            ),
          ),
          IconButton(
            key: const ValueKey('story-share'),
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            color: Colors.white,
            tooltip: 'Compartir historia',
          ),
          if (onDelete != null)
            IconButton(
              key: const ValueKey('story-delete'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppTheme.rose,
              tooltip: 'Eliminar historia',
            ),
        ],
      ),
    );
  }
}

class _StoryMedia extends StatelessWidget {
  const _StoryMedia({
    required this.story,
    required this.paused,
    required this.videoMuted,
  });

  final Story story;
  final bool paused;
  final bool videoMuted;

  @override
  Widget build(BuildContext context) {
    final elements = story.elements.isEmpty && story.text.isNotEmpty
        ? [
            StoryElement(
              id: 'legacy-text',
              type: StoryElementType.text,
              content: story.text,
              position: const Offset(0.5, 0.46),
              scale: 1.18,
            ),
          ]
        : story.elements;
    return StoryCanvas(
      contentType: story.contentType,
      imageAsset: story.imageAsset,
      imageBytes: story.imageBytes,
      mediaPath: story.mediaPath,
      backgroundColors: story.backgroundColors,
      elements: elements,
      mediaScale: story.mediaScale,
      mediaOffset: story.mediaOffset,
      mediaRotation: story.mediaRotation,
      visualFilter: story.visualFilter,
      videoTrimStartSeconds: story.videoTrimStartSeconds,
      videoTrimEndSeconds: story.videoTrimEndSeconds,
      videoMuted: videoMuted,
      playbackPaused: paused,
    );
  }
}
