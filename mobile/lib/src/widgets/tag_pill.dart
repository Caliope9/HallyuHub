import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.selected = false,
    this.color,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.rose;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? accent : accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: selected ? 0 : 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
