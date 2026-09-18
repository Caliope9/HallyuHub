import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum HomeFeature { viral, outfit }

class HomeFeaturePlaceholderScreen extends StatelessWidget {
  const HomeFeaturePlaceholderScreen({super.key, required this.feature});

  final HomeFeature feature;

  @override
  Widget build(BuildContext context) {
    final isViral = feature == HomeFeature.viral;
    final title = isViral ? '🔥 Viral' : '👕 Outfit';
    final subtitle = isViral
        ? 'Lo más popular de HallyuHub'
        : 'K-pop style & fashion';
    final detail = isViral
        ? 'Estamos preparando este espacio para descubrir lo que la comunidad está disfrutando ahora.'
        : 'Estamos preparando este espacio para compartir inspiración y estilo K-pop.';
    final accent = isViral ? AppTheme.rose : AppTheme.violet;

    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.panelRaised.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isViral
                          ? Icons.local_fire_department_rounded
                          : Icons.checkroom_rounded,
                      size: 42,
                      color: accent,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      detail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Volver a Inicio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: accent.withValues(alpha: 0.7)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
