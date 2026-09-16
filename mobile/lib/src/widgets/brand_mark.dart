import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HallyuBrandAssets {
  const HallyuBrandAssets._();

  static const logoFull = 'assets/brand/hallyuhub_logo_full.png';
  static const icon = 'assets/brand/hallyuhub_icon.png';
  static const iconSmall = 'assets/brand/hallyuhub_icon_small.png';
  static const wordmark = 'assets/brand/hallyuhub_wordmark.png';
  static const splash = 'assets/brand/hallyuhub_splash.png';
  static const topbar = 'assets/brand/hallyuhub_topbar.png';
  static const appIcon = 'assets/brand/hallyuhub_app_icon.png';
}

class HallyuBrandIcon extends StatelessWidget {
  const HallyuBrandIcon({
    super.key,
    required this.size,
    this.radiusFactor = 0.26,
    this.glow = true,
  });

  final double size;
  final double radiusFactor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * radiusFactor),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppTheme.cyan.withValues(alpha: 0.2),
                  blurRadius: size * 0.34,
                  offset: Offset(0, size * 0.14),
                ),
                BoxShadow(
                  color: AppTheme.rose.withValues(alpha: 0.16),
                  blurRadius: size * 0.28,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * radiusFactor),
        child: Image.asset(
          HallyuBrandAssets.icon,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class HallyuBrandWordmark extends StatelessWidget {
  const HallyuBrandWordmark({
    super.key,
    this.fontSize = 34,
    this.compact = false,
  });

  final double fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      'HallyuHub',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
        shadows: [
          Shadow(
            color: AppTheme.rose.withValues(alpha: compact ? 0.45 : 0.7),
            blurRadius: compact ? 12 : 22,
          ),
        ],
      ),
    );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF72E8FF),
          Color(0xFF7A8BFF),
          AppTheme.violet,
          Color(0xFFFF6ACD),
        ],
      ).createShader(bounds),
      child: text,
    );
  }
}

class HallyuBrandLockup extends StatelessWidget {
  const HallyuBrandLockup({
    super.key,
    this.iconSize = 66,
    this.wordmarkSize = 34,
    this.vertical = true,
    this.compact = false,
  });

  final double iconSize;
  final double wordmarkSize;
  final bool vertical;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = HallyuBrandIcon(size: iconSize, glow: !compact);
    final wordmark = HallyuBrandWordmark(
      fontSize: wordmarkSize,
      compact: compact,
    );

    if (!vertical) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: compact ? 9 : 12),
          Flexible(child: wordmark),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(height: compact ? 10 : 16),
        wordmark,
      ],
    );
  }
}
