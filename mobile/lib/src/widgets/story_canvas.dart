import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class StoryCanvas extends StatelessWidget {
  const StoryCanvas({
    super.key,
    required this.contentType,
    required this.imageAsset,
    required this.imageBytes,
    required this.mediaPath,
    required this.backgroundColors,
    required this.elements,
    required this.mediaScale,
    required this.mediaOffset,
    required this.mediaRotation,
    required this.visualFilter,
    this.videoTrimStartSeconds = 0,
    this.videoTrimEndSeconds,
    this.videoMuted = false,
    this.mediaFit = BoxFit.cover,
    this.editable = false,
    this.playbackPaused = false,
    this.selectedMedia = false,
    this.selectedElementId,
    this.onMediaSelected,
    this.onElementSelected,
    this.onElementChanged,
    this.onMediaChanged,
    this.onManipulationStart,
    this.onManipulationUpdate,
    this.onManipulationEnd,
    this.onVideoDurationChanged,
  });

  factory StoryCanvas.fromStory(Story story) {
    return StoryCanvas(
      contentType: story.contentType,
      imageAsset: story.imageAsset,
      imageBytes: story.imageBytes,
      mediaPath: story.mediaPath,
      backgroundColors: story.backgroundColors,
      elements: story.elements,
      mediaScale: story.mediaScale,
      mediaOffset: story.mediaOffset,
      mediaRotation: story.mediaRotation,
      visualFilter: story.visualFilter,
      videoTrimStartSeconds: story.videoTrimStartSeconds,
      videoTrimEndSeconds: story.videoTrimEndSeconds,
      videoMuted: story.videoMuted,
    );
  }

  final StoryContentType contentType;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final List<Color> backgroundColors;
  final List<StoryElement> elements;
  final double mediaScale;
  final Offset mediaOffset;
  final double mediaRotation;
  final StoryVisualFilter visualFilter;
  final double videoTrimStartSeconds;
  final double? videoTrimEndSeconds;
  final bool videoMuted;
  final BoxFit mediaFit;
  final bool editable;
  final bool playbackPaused;
  final bool selectedMedia;
  final String? selectedElementId;
  final VoidCallback? onMediaSelected;
  final ValueChanged<String>? onElementSelected;
  final ValueChanged<StoryElement>? onElementChanged;
  final void Function(double scale, Offset offset, double rotation)?
  onMediaChanged;
  final void Function(String targetId, Offset globalFocalPoint)?
  onManipulationStart;
  final void Function(String targetId, Offset globalFocalPoint)?
  onManipulationUpdate;
  final ValueChanged<String>? onManipulationEnd;
  final ValueChanged<Duration>? onVideoDurationChanged;

  static const mediaTargetId = 'story-canvas-media';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: backgroundColors,
                  ),
                ),
              ),
              if (_hasMedia)
                _TransformableMedia(
                  contentType: contentType,
                  imageAsset: imageAsset,
                  imageBytes: imageBytes,
                  mediaPath: mediaPath,
                  scale: mediaScale,
                  offset: mediaOffset,
                  rotation: mediaRotation,
                  trimStartSeconds: videoTrimStartSeconds,
                  trimEndSeconds: videoTrimEndSeconds,
                  muted: videoMuted,
                  fit: mediaFit,
                  editable: editable,
                  paused: playbackPaused,
                  selected: selectedMedia,
                  onSelected: onMediaSelected,
                  onChanged: onMediaChanged,
                  onManipulationStart: onManipulationStart,
                  onManipulationUpdate: onManipulationUpdate,
                  onManipulationEnd: onManipulationEnd,
                  onVideoDurationChanged: onVideoDurationChanged,
                ),
              for (final element in elements)
                Positioned(
                  left: element.position.dx * size.width,
                  top: element.position.dy * size.height,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: _TransformableStoryElement(
                      element: element,
                      canvasSize: size,
                      selected: element.id == selectedElementId,
                      editable: editable,
                      onSelected: onElementSelected,
                      onChanged: onElementChanged,
                      onManipulationStart: onManipulationStart,
                      onManipulationUpdate: onManipulationUpdate,
                      onManipulationEnd: onManipulationEnd,
                    ),
                  ),
                ),
              if (visualFilter != StoryVisualFilter.original)
                IgnorePointer(child: StoryFilterOverlay(filter: visualFilter)),
            ],
          ),
        );
      },
    );
  }

  bool get _hasMedia =>
      imageBytes != null || imageAsset.isNotEmpty || mediaPath.isNotEmpty;
}

class _TransformableMedia extends StatefulWidget {
  const _TransformableMedia({
    required this.contentType,
    required this.imageAsset,
    required this.imageBytes,
    required this.mediaPath,
    required this.scale,
    required this.offset,
    required this.rotation,
    required this.trimStartSeconds,
    required this.trimEndSeconds,
    required this.muted,
    required this.fit,
    required this.editable,
    required this.paused,
    required this.selected,
    required this.onSelected,
    required this.onChanged,
    required this.onManipulationStart,
    required this.onManipulationUpdate,
    required this.onManipulationEnd,
    required this.onVideoDurationChanged,
  });

  final StoryContentType contentType;
  final String imageAsset;
  final Uint8List? imageBytes;
  final String mediaPath;
  final double scale;
  final Offset offset;
  final double rotation;
  final double trimStartSeconds;
  final double? trimEndSeconds;
  final bool muted;
  final BoxFit fit;
  final bool editable;
  final bool paused;
  final bool selected;
  final VoidCallback? onSelected;
  final void Function(double scale, Offset offset, double rotation)? onChanged;
  final void Function(String targetId, Offset globalFocalPoint)?
  onManipulationStart;
  final void Function(String targetId, Offset globalFocalPoint)?
  onManipulationUpdate;
  final ValueChanged<String>? onManipulationEnd;
  final ValueChanged<Duration>? onVideoDurationChanged;

  @override
  State<_TransformableMedia> createState() => _TransformableMediaState();
}

class _TransformableMediaState extends State<_TransformableMedia> {
  late double _baseScale;
  late Offset _baseOffset;
  late double _baseRotation;
  late Offset _startFocalPoint;

  void _start(ScaleStartDetails details) {
    widget.onSelected?.call();
    _baseScale = widget.scale;
    _baseOffset = widget.offset;
    _baseRotation = widget.rotation;
    _startFocalPoint = details.focalPoint;
    widget.onManipulationStart?.call(
      StoryCanvas.mediaTargetId,
      details.focalPoint,
    );
  }

  void _update(ScaleUpdateDetails details) {
    final dragOffset = details.focalPoint - _startFocalPoint;
    widget.onChanged?.call(
      (_baseScale * details.scale).clamp(0.55, 4),
      Offset(
        (_baseOffset.dx + dragOffset.dx).clamp(-160, 160),
        (_baseOffset.dy + dragOffset.dy).clamp(-220, 220),
      ),
      (_baseRotation + details.rotation).clamp(-0.7, 0.7),
    );
    widget.onManipulationUpdate?.call(
      StoryCanvas.mediaTargetId,
      details.focalPoint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media =
        widget.contentType == StoryContentType.video &&
            widget.mediaPath.isNotEmpty
        ? _StoryVideo(
            path: widget.mediaPath,
            paused: widget.paused,
            muted: widget.muted,
            trimStartSeconds: widget.trimStartSeconds,
            trimEndSeconds: widget.trimEndSeconds,
            onDurationChanged: widget.onVideoDurationChanged,
          )
        : widget.imageBytes != null
        ? Image.memory(
            widget.imageBytes!,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
          )
        : widget.imageAsset.startsWith('http://') ||
              widget.imageAsset.startsWith('https://')
        ? Image.network(
            widget.imageAsset,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppTheme.nightSoft,
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white70),
              ),
            ),
          )
        : Image.asset(
            widget.imageAsset,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
          );
    final transformed = Transform.translate(
      offset: widget.offset,
      child: Transform.rotate(
        angle: widget.rotation,
        child: Transform.scale(
          scale: widget.scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: widget.selected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                      width: 1.4,
                    )
                  : null,
            ),
            child: SizedBox.expand(child: media),
          ),
        ),
      ),
    );
    if (!widget.editable) return transformed;
    return GestureDetector(
      key: const ValueKey('story-editor-media'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSelected,
      onScaleStart: _start,
      onScaleUpdate: _update,
      onScaleEnd: (_) =>
          widget.onManipulationEnd?.call(StoryCanvas.mediaTargetId),
      child: transformed,
    );
  }
}

class _TransformableStoryElement extends StatefulWidget {
  const _TransformableStoryElement({
    required this.element,
    required this.canvasSize,
    required this.selected,
    required this.editable,
    required this.onSelected,
    required this.onChanged,
    required this.onManipulationStart,
    required this.onManipulationUpdate,
    required this.onManipulationEnd,
  });

  final StoryElement element;
  final Size canvasSize;
  final bool selected;
  final bool editable;
  final ValueChanged<String>? onSelected;
  final ValueChanged<StoryElement>? onChanged;
  final void Function(String targetId, Offset globalFocalPoint)?
  onManipulationStart;
  final void Function(String targetId, Offset globalFocalPoint)?
  onManipulationUpdate;
  final ValueChanged<String>? onManipulationEnd;

  @override
  State<_TransformableStoryElement> createState() =>
      _TransformableStoryElementState();
}

class _TransformableStoryElementState
    extends State<_TransformableStoryElement> {
  late Offset _basePosition;
  late double _baseScale;
  late double _baseRotation;
  late Offset _startFocalPoint;

  void _start(ScaleStartDetails details) {
    widget.onSelected?.call(widget.element.id);
    _basePosition = widget.element.position;
    _baseScale = widget.element.scale;
    _baseRotation = widget.element.rotation;
    _startFocalPoint = details.focalPoint;
    widget.onManipulationStart?.call(widget.element.id, details.focalPoint);
  }

  void _update(ScaleUpdateDetails details) {
    final dragOffset = details.focalPoint - _startFocalPoint;
    widget.onChanged?.call(
      widget.element.copyWith(
        position: Offset(
          (_basePosition.dx + dragOffset.dx / widget.canvasSize.width).clamp(
            0.06,
            0.94,
          ),
          (_basePosition.dy + dragOffset.dy / widget.canvasSize.height).clamp(
            0.06,
            0.94,
          ),
        ),
        scale: (_baseScale * details.scale).clamp(0.45, 3.5),
        rotation: (_baseRotation + details.rotation).clamp(-1.2, 1.2),
      ),
    );
    widget.onManipulationUpdate?.call(widget.element.id, details.focalPoint);
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final child = Container(
      constraints: BoxConstraints(maxWidth: widget.canvasSize.width * 0.82),
      padding: element.type == StoryElementType.text
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: element.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: widget.selected
            ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.4)
            : null,
      ),
      child: element.type == StoryElementType.image
          ? _StoryElementImage(element: element)
          : Text(
              element.content,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: element.color,
                fontSize: element.type == StoryElementType.text ? 24 : 42,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
    );
    final transformed = Transform.rotate(
      angle: element.rotation,
      child: Transform.scale(scale: element.scale, child: child),
    );
    if (!widget.editable) return transformed;
    return GestureDetector(
      key: ValueKey('story-element-${element.id}'),
      behavior: HitTestBehavior.translucent,
      onTap: () => widget.onSelected?.call(element.id),
      onScaleStart: _start,
      onScaleUpdate: _update,
      onScaleEnd: (_) => widget.onManipulationEnd?.call(widget.element.id),
      child: transformed,
    );
  }
}

class _StoryElementImage extends StatelessWidget {
  const _StoryElementImage({required this.element});

  final StoryElement element;

  @override
  Widget build(BuildContext context) {
    final imageBytes = element.imageBytes;
    final image = imageBytes != null
        ? Image.memory(imageBytes, fit: BoxFit.cover)
        : element.content.startsWith('assets/')
        ? Image.asset(element.content, fit: BoxFit.cover)
        : const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEF4F7A), Color(0xFFA855F7)],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: ValueKey('story-element-image-${element.id}'),
        width: 132,
        height: 170,
        child: image,
      ),
    );
  }
}

class StoryFilterOverlay extends StatelessWidget {
  const StoryFilterOverlay({super.key, required this.filter});

  final StoryVisualFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = switch (filter) {
      StoryVisualFilter.hallyuGlow => const [
        Color(0x4DEF4F7A),
        Color(0x334DE7FF),
        Color(0x55A855F7),
      ],
      StoryVisualFilter.neonPink => const [
        Color(0x66FF2D75),
        Color(0x22FFFFFF),
      ],
      StoryVisualFilter.softPastel => const [
        Color(0x55FFD6E8),
        Color(0x44A7F3FF),
      ],
      StoryVisualFilter.concertLight => const [
        Color(0x44FFE08A),
        Color(0x334DE7FF),
        Color(0x55080311),
      ],
      StoryVisualFilter.vintage => const [Color(0x44F7C59F), Color(0x332C1B12)],
      StoryVisualFilter.blackPink => const [
        Color(0x88080311),
        Color(0x55FF4F9A),
      ],
      StoryVisualFilter.purpleStage => const [
        Color(0x66101833),
        Color(0x66A855F7),
        Color(0x224DE7FF),
      ],
      StoryVisualFilter.original => const [Colors.transparent],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _StoryVideo extends StatefulWidget {
  const _StoryVideo({
    required this.path,
    required this.paused,
    required this.muted,
    required this.trimStartSeconds,
    required this.trimEndSeconds,
    required this.onDurationChanged,
  });

  final String path;
  final bool paused;
  final bool muted;
  final double trimStartSeconds;
  final double? trimEndSeconds;
  final ValueChanged<Duration>? onDurationChanged;

  @override
  State<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<_StoryVideo> {
  VideoPlayerController? _controller;
  bool _seekingToStart = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _StoryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _prepare();
    } else {
      if (oldWidget.paused != widget.paused) _syncPlayback();
      if (oldWidget.muted != widget.muted) _syncVolume();
      if (oldWidget.trimStartSeconds != widget.trimStartSeconds ||
          oldWidget.trimEndSeconds != widget.trimEndSeconds) {
        _syncTrim();
      }
    }
  }

  Future<void> _prepare() async {
    final previousController = _controller;
    previousController?.removeListener(_enforceTrim);
    await previousController?.dispose();
    final path = widget.path;
    final uri = kIsWeb || path.startsWith('http') || path.startsWith('blob:')
        ? Uri.parse(path)
        : Uri.file(path);
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(widget.muted ? 0 : 1);
      controller.addListener(_enforceTrim);
      await controller.seekTo(_trimStart);
      if (!widget.paused) await controller.play();
      widget.onDurationChanged?.call(controller.value.duration);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (widget.paused) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (_) {}
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
    try {
      final position = controller.value.position;
      if (position < _trimStart || position >= _trimEnd) {
        await controller.seekTo(_trimStart);
      }
    } catch (_) {}
  }

  void _enforceTrim() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _seekingToStart ||
        controller.value.position < _trimEnd) {
      return;
    }
    _seekingToStart = true;
    controller
        .seekTo(_trimStart)
        .then((_) async {
          if (!widget.paused) await controller.play();
        })
        .whenComplete(() => _seekingToStart = false);
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
    _controller?.removeListener(_enforceTrim);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Icon(Icons.videocam_outlined, color: Colors.white70, size: 46),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
