import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HallyuBackdrop extends StatelessWidget {
  const HallyuBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060913), AppTheme.night, Color(0xFF080A16)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(child: _HallyuEdgeLight()),
          child,
        ],
      ),
    );
  }
}

class _HallyuEdgeLight extends StatelessWidget {
  const _HallyuEdgeLight();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.violet.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.transparent,
            AppTheme.rose.withValues(alpha: 0.08),
          ],
          stops: const [0, 0.28, 0.72, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppTheme.cyan.withValues(alpha: 0.055),
              Colors.transparent,
              AppTheme.rose.withValues(alpha: 0.04),
            ],
          ),
        ),
      ),
    );
  }
}

class HallyuGlassPanel extends StatelessWidget {
  const HallyuGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.accent = AppTheme.violet,
    this.blur = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color accent;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.075),
                AppTheme.panel.withValues(alpha: 0.92),
                accent.withValues(alpha: 0.055),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class HallyuSectionHeading extends StatelessWidget {
  const HallyuSectionHeading({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.cyan, AppTheme.rose],
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.rose,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}
