import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/post_video_player.dart';

enum ProfileVideoKind { drop, fancam }

class ProfileVideoPlayerScreen extends StatelessWidget {
  const ProfileVideoPlayerScreen.drop({super.key, required DropClip this.drop})
    : fancam = null,
      kind = ProfileVideoKind.drop;

  const ProfileVideoPlayerScreen.fancam({
    super.key,
    required Fancam this.fancam,
  }) : drop = null,
       kind = ProfileVideoKind.fancam;

  final ProfileVideoKind kind;
  final DropClip? drop;
  final Fancam? fancam;

  bool get _isDrop => kind == ProfileVideoKind.drop;

  String get _title {
    if (_isDrop) {
      final clip = drop!;
      if (clip.caption.trim().isNotEmpty) return clip.caption.trim();
      return clip.title.trim().isEmpty ? 'Drop' : clip.title.trim();
    }
    final item = fancam!;
    if (item.caption.trim().isNotEmpty) return item.caption.trim();
    return item.title.trim().isEmpty ? 'Fancam' : item.title.trim();
  }

  String get _subtitle {
    if (_isDrop) {
      final clip = drop!;
      return [
        if (clip.artist.trim().isNotEmpty) clip.artist.trim(),
        if (clip.location.trim().isNotEmpty) clip.location.trim(),
      ].join(' · ');
    }
    final item = fancam!;
    return [
      if (item.artist.trim().isNotEmpty) item.artist.trim(),
      if (item.energy.trim().isNotEmpty) item.energy.trim(),
      if (item.audio.trim().isNotEmpty) item.audio.trim(),
      if (item.location.trim().isNotEmpty) item.location.trim(),
    ].join(' · ');
  }

  String get _videoPath => _isDrop ? drop!.videoPath : fancam!.videoPath;

  String get _duration =>
      _isDrop ? _formatSeconds(drop!.videoDurationSeconds) : fancam!.duration;

  String get _likes => _isDrop ? drop!.likes : fancam!.likes;

  String get _comments => _isDrop ? drop!.comments : fancam!.comments;

  String _formatSeconds(double? value) {
    final seconds = value?.round();
    if (seconds == null || seconds <= 0) return 'Video';
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final label = _isDrop ? 'Drop' : 'Fancam';
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: Text(
          'Ver $label',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.nightSoft, AppTheme.violet],
                    ),
                  ),
                  child: _videoPath.trim().isEmpty
                      ? const _MissingVideoState()
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            PostVideoPlayer(
                              path: _videoPath,
                              muted: false,
                              fit: _isDrop ? BoxFit.cover : BoxFit.contain,
                            ),
                            Positioned(
                              left: 14,
                              top: 14,
                              child: _VideoBadge(label: label),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(icon: Icons.play_arrow_rounded, label: _duration),
                _MetricPill(
                  icon: Icons.star_rounded,
                  label: '$_likes estrellas',
                ),
                _MetricPill(
                  icon: Icons.mode_comment_outlined,
                  label: '$_comments comentarios',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingVideoState extends StatelessWidget {
  const _MissingVideoState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white70,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'No encontramos el video de este contenido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
