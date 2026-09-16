import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VideoLoadingBackdrop extends StatelessWidget {
  const VideoLoadingBackdrop({
    super.key,
    this.label = 'Cargando video...',
    this.showSpinner = true,
  });

  final String label;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.night,
            AppTheme.violet.withValues(alpha: 0.42),
            AppTheme.nightSoft,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSpinner) ...[
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.cyan,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (label.isNotEmpty)
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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

class VideoErrorBackdrop extends StatelessWidget {
  const VideoErrorBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoLoadingBackdrop(label: '', showSpinner: false);
  }
}
