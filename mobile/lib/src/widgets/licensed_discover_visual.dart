import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LicensedDiscoverVisual extends StatelessWidget {
  const LicensedDiscoverVisual({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageAsset = '',
    this.imageUrl = '',
    this.imageSource = '',
    this.imageLicense = 'HallyuHub placeholder',
    this.attribution = 'Visual abstracto generado por HallyuHub',
    this.author = 'HallyuHub',
    this.licenseUrl = '',
    this.showAttribution = false,
    this.fit = BoxFit.cover,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final String imageUrl;
  final String imageSource;
  final String imageLicense;
  final String attribution;
  final String author;
  final String licenseUrl;
  final bool showAttribution;
  final BoxFit fit;

  bool get _hasLicensedImage {
    final license = imageLicense.toLowerCase();
    final source = imageSource.toLowerCase();
    final hasMedia = imageAsset.isNotEmpty || imageUrl.isNotEmpty;
    final placeholder =
        license.contains('placeholder') ||
        source.contains('placeholder') ||
        attribution.toLowerCase().contains('abstracto');
    return hasMedia && !placeholder && license.isNotEmpty && source.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final child = _hasLicensedImage ? _licensedImage() : _premiumPlaceholder();
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showAttribution)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: _AttributionPill(
              label: _hasLicensedImage
                  ? '$imageLicense · $attribution'
                  : 'Placeholder legal · HallyuHub',
            ),
          ),
      ],
    );
  }

  Widget _licensedImage() {
    if (imageUrl.isNotEmpty) {
      return Image.network(imageUrl, fit: fit);
    }
    return Image.asset(imageAsset, fit: fit);
  }

  Widget _premiumPlaceholder() {
    final colors = _paletteFor(title);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            top: 18,
            child: Transform.rotate(
              angle: -0.42,
              child: Container(
                width: 112,
                height: 22,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 86,
              height: 86,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Text(
                _initials(title),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: showAttribution ? 38 : 12,
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributionPill extends StatelessWidget {
  const _AttributionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<Color> _paletteFor(String seed) {
  final value = seed.codeUnits.fold<int>(0, (sum, code) => sum + code);
  final palettes = [
    const [Color(0xFFEF4F7A), Color(0xFFA855F7), Color(0xFF080311)],
    const [Color(0xFF65E4FF), Color(0xFF4C6FFF), Color(0xFF080311)],
    const [Color(0xFFFFB703), Color(0xFFEF4F7A), Color(0xFF150B24)],
    const [Color(0xFF00A6A6), Color(0xFFA855F7), Color(0xFF080311)],
  ];
  return palettes[value % palettes.length];
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'HH';
  if (parts.length == 1) {
    return parts.single
        .substring(0, parts.single.length.clamp(1, 2))
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
