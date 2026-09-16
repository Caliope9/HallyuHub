import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/video_playback_coordinator.dart';
import '../theme/app_theme.dart';

void _logPerformance(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

class PostVideoPlayer extends StatefulWidget {
  const PostVideoPlayer({
    super.key,
    required this.path,
    this.muted = true,
    this.trimStartSeconds = 0,
    this.trimEndSeconds,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
  });

  final String path;
  final bool muted;
  final double trimStartSeconds;
  final double? trimEndSeconds;
  final BoxFit fit;
  final bool autoPlay;

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  final Object _playbackOwner = Object();
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _playing = false;
  bool _seekingToStart = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant PostVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _prepare();
      return;
    }
    if (oldWidget.muted != widget.muted) _syncVolume();
    if (oldWidget.trimStartSeconds != widget.trimStartSeconds ||
        oldWidget.trimEndSeconds != widget.trimEndSeconds) {
      _syncTrim();
    }
  }

  Future<void> _prepare() async {
    final stopwatch = Stopwatch()..start();
    _logPerformance('PERF_POST_VIDEO_INIT_START path=${widget.path}');
    VideoPlaybackCoordinator.release(_playbackOwner);
    final previous = _controller;
    previous?.removeListener(_handleTick);
    await previous?.dispose();
    if (!mounted) return;
    setState(() {
      _controller = null;
      _initializing = true;
      _playing = false;
      _error = '';
    });
    final path = widget.path;
    if (path.isEmpty) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Video no disponible.';
      });
      return;
    }
    final controller = VideoPlayerController.networkUrl(_videoUri(path));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.seekTo(_trimStart);
      controller.addListener(_handleTick);
      if (!mounted) return;
      setState(() => _initializing = false);
      if (widget.autoPlay) await _startPlayback(reason: 'auto_play');
      _logPerformance(
        'PERF_POST_VIDEO_INIT_OK elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _initializing = false;
        _playing = false;
        _error =
            'No pudimos cargar este video. Probá de nuevo en unos segundos.';
      });
      _logPerformance(
        'PERF_POST_VIDEO_INIT_ERROR elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  Future<void> _syncVolume() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setVolume(widget.muted ? 0 : 1);
    } catch (_) {}
  }

  Future<void> _syncTrim() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    if (position < _trimStart || position >= _trimEnd) {
      try {
        await controller.seekTo(_trimStart);
      } catch (_) {}
    }
  }

  void _handleTick() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _seekingToStart ||
        controller.value.position < _trimEnd) {
      return;
    }
    _seekingToStart = true;
    _pausePlayback(
      reason: 'trim_end',
    ).then((_) => controller.seekTo(_trimStart)).whenComplete(() {
      _seekingToStart = false;
    });
  }

  Future<void> _startPlayback({required String reason}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final claimed = await VideoPlaybackCoordinator.claim(
      owner: _playbackOwner,
      source: 'post_video',
      pause: () => _pausePlayback(reason: 'another_video', release: false),
    );
    if (!claimed || !mounted || !identical(controller, _controller)) return;
    try {
      if (controller.value.position >= _trimEnd) {
        await controller.seekTo(_trimStart);
      }
      await controller.play();
      if (!mounted) return;
      setState(() => _playing = true);
      _logPerformance('VIDEO_PLAYBACK_START source=post reason=$reason');
    } catch (_) {
      VideoPlaybackCoordinator.release(_playbackOwner);
      if (!mounted) return;
      setState(
        () => _error = 'No pudimos reproducir este video en este momento.',
      );
    }
  }

  Future<void> _pausePlayback({
    required String reason,
    bool release = true,
  }) async {
    if (release) VideoPlaybackCoordinator.release(_playbackOwner);
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pause();
      } catch (_) {}
    }
    if (mounted && _playing) setState(() => _playing = false);
    _logPerformance('VIDEO_PLAYBACK_PAUSE source=post reason=$reason');
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _pausePlayback(reason: 'user');
    } else {
      await _startPlayback(reason: 'user');
    }
  }

  Duration get _trimStart =>
      Duration(milliseconds: (widget.trimStartSeconds * 1000).round());

  Duration get _trimEnd {
    final duration = _controller?.value.duration ?? Duration.zero;
    final requested = widget.trimEndSeconds;
    if (requested == null) return duration;
    final trimmed = Duration(milliseconds: (requested * 1000).round());
    return trimmed < duration ? trimmed : duration;
  }

  @override
  void dispose() {
    VideoPlaybackCoordinator.release(_playbackOwner);
    _controller?.removeListener(_handleTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    return GestureDetector(
      key: ValueKey('post-video-player-${widget.path}'),
      behavior: HitTestBehavior.opaque,
      onTap: initialized ? _togglePlayback : null,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (initialized)
              FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            if (_initializing)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppTheme.cyan,
                ),
              ),
            if (_error.isNotEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white70,
                      size: 42,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            if (initialized)
              Center(
                child: AnimatedOpacity(
                  opacity: _playing ? 0 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.42),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            if (initialized)
              Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _playing ? 'Pausar' : 'Reproducir',
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
              ),
          ],
        ),
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
