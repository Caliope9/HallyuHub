import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'hub_avatar.dart';

class StoryStatsSheet extends StatelessWidget {
  const StoryStatsSheet({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vistas y reacciones',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _Stat(value: '${story.views}', label: 'vistas'),
                const SizedBox(width: 8),
                _Stat(value: '${story.stars}', label: 'estrellas'),
                const SizedBox(width: 8),
                _Stat(value: '${story.viewers.length}', label: 'fans'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Vieron tu historia',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            if (story.viewers.isEmpty)
              Text(
                'Todavía no hay vistas. Cuando alguien vea tu story, va a aparecer acá.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              ...story.viewers.map((viewer) => _ViewerRow(viewer: viewer)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerRow extends StatelessWidget {
  const _ViewerRow({required this.viewer});

  final StoryViewer viewer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          HubAvatar(asset: viewer.avatarAsset, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewer.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${viewer.username} · ${viewer.action}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (viewer.starred)
            const Icon(Icons.star_rounded, color: AppTheme.amber, size: 20),
        ],
      ),
    );
  }
}
