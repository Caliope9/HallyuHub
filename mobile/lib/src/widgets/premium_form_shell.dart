import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum PremiumFormVisual { community, event, create, profile, store, report }

class PremiumFormShell extends StatelessWidget {
  const PremiumFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.visual,
    required this.child,
    this.scrollController,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 28),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PremiumFormVisual visual;
  final Widget child;
  final ScrollController? scrollController;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF060913)),
      child: ListView(
        controller: scrollController,
        padding: padding,
        children: [
          const PremiumSheetHandle(),
          const SizedBox(height: 14),
          PremiumFormHero(
            title: title,
            subtitle: subtitle,
            icon: icon,
            visual: visual,
            leading: leading,
            trailing: trailing,
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class PremiumSheetHandle extends StatelessWidget {
  const PremiumSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class PremiumFormHero extends StatelessWidget {
  const PremiumFormHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.visual,
    this.leading,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PremiumFormVisual visual;
  final Widget? leading;
  final Widget? trailing;

  Color get _accent => switch (visual) {
    PremiumFormVisual.community => AppTheme.cyan,
    PremiumFormVisual.event => AppTheme.rose,
    PremiumFormVisual.create => AppTheme.violet,
    PremiumFormVisual.profile => AppTheme.cyan,
    PremiumFormVisual.store => const Color(0xFF7C8CFF),
    PremiumFormVisual.report => const Color(0xFFFFB657),
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 126),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF10172B),
                accent.withValues(alpha: 0.14),
                AppTheme.rose.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -28,
                child: _HeroRings(accent: accent),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ] else ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const SizedBox(width: 13),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.67),
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroRings extends StatelessWidget {
  const _HeroRings({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 136,
        height: 136,
        child: CustomPaint(painter: _HeroRingsPainter(accent)),
      ),
    );
  }
}

class _HeroRingsPainter extends CustomPainter {
  const _HeroRingsPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.56, size.height * 0.42);
    for (var index = 0; index < 3; index++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.18 - (index * 0.04));
      canvas.drawCircle(center, 34 + (index * 19), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroRingsPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class PremiumFormSection extends StatelessWidget {
  const PremiumFormSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.children,
    this.accent = AppTheme.violet,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.38),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (icon != null) ...[
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ..._withSpacing(children),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items) {
    if (items.length < 2) return items;
    return [
      for (var index = 0; index < items.length; index++) ...[
        items[index],
        if (index != items.length - 1) const SizedBox(height: 10),
      ],
    ];
  }
}

class PremiumActionTile extends StatelessWidget {
  const PremiumActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.14), const Color(0xFF11182A)],
            ),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
