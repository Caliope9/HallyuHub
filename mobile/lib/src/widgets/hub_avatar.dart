import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HubAvatar extends StatelessWidget {
  const HubAvatar({
    super.key,
    required this.asset,
    this.size = 48,
    this.isLive = false,
    this.fallbackLabel = 'H',
    this.fallbackColors,
  });

  final String asset;
  final double size;
  final bool isLive;
  final String fallbackLabel;
  final List<Color>? fallbackColors;

  @override
  Widget build(BuildContext context) {
    final normalizedAsset = asset.trim();
    final shouldUseFallback =
        normalizedAsset.isEmpty || _isDemoFallbackAsset(normalizedAsset);
    final imageBytes = shouldUseFallback ? null : _avatarBytes(normalizedAsset);
    final avatar = ClipOval(
      child: shouldUseFallback
          ? _fallbackAvatar()
          : imageBytes == null
          ? _avatarImage(normalizedAsset)
          : Image.memory(
              imageBytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
    );

    if (!isLive) return avatar;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.rose, AppTheme.amber, AppTheme.teal],
        ),
      ),
      child: avatar,
    );
  }

  Widget _avatarImage(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackAvatar(),
      );
    }
    return Image.asset(
      source,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallbackAvatar(),
    );
  }

  Widget _fallbackAvatar() {
    final safeLabel = fallbackLabel.trim().isEmpty
        ? 'H'
        : fallbackLabel.trim().characters.first.toUpperCase();
    final colors = fallbackColors != null && fallbackColors!.length >= 2
        ? fallbackColors!
        : const [AppTheme.nightSoft, AppTheme.violet, AppTheme.cyan];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: size < 36 ? 1 : 1.6,
        ),
      ),
      child: Center(
        child: Text(
          safeLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .46,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }

  bool _isDemoFallbackAsset(String value) {
    final normalized = value.toLowerCase();
    return normalized.startsWith('assets/demo-users/') ||
        normalized.contains('/assets/demo-users/');
  }

  Uint8List? _avatarBytes(String value) {
    if (!value.startsWith('data:image/')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}
