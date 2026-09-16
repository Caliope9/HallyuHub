import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import 'hub_avatar.dart';
import 'premium_profile_visuals.dart';

class StoreProfileCard extends StatelessWidget {
  const StoreProfileCard({
    super.key,
    required this.store,
    required this.avatarAsset,
    required this.followersLabel,
    required this.postsLabel,
    required this.savesLabel,
    required this.isOwnProfile,
    this.following = false,
    this.busyFollow = false,
    this.onFollow,
    this.onMessage,
    this.onSettings,
    this.onReport,
  });

  final StoreProfile store;
  final String avatarAsset;
  final String followersLabel;
  final String postsLabel;
  final String savesLabel;
  final bool isOwnProfile;
  final bool following;
  final bool busyFollow;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onSettings;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final location = _storeLocation(store);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileVisualSectionHeader(
          title: isOwnProfile ? 'Soy tienda' : 'Tienda',
          icon: Icons.storefront_rounded,
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('store-profile-card'),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF15142A),
                Color(0xFF261332),
                Color(0xFF0B2330),
                Color(0xFF090D19),
              ],
              stops: [0, 0.36, 0.72, 1],
            ),
            border: Border.all(
              color: AppTheme.rose.withValues(alpha: 0.44),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.rose.withValues(alpha: 0.16),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.rose, AppTheme.violet, AppTheme.cyan],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.rose.withValues(alpha: 0.28),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: HubAvatar(
                      asset: avatarAsset,
                      size: 78,
                      isLive: store.isActive,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            const _StoreBadge(
                              icon: Icons.storefront_rounded,
                              label: 'Tienda',
                              color: AppTheme.rose,
                            ),
                            if (store.isVerified)
                              const _StoreBadge(
                                icon: Icons.verified_rounded,
                                label: 'Verificada',
                                color: AppTheme.cyan,
                              )
                            else
                              _StoreBadge(
                                icon: Icons.hourglass_top_rounded,
                                label: store.status.label,
                                color: _statusColor(store.status),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store.storeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            location,
                            style: TextStyle(
                              color: AppTheme.cyan.withValues(alpha: 0.74),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isOwnProfile && onSettings != null)
                    IconButton.filledTonal(
                      onPressed: onSettings,
                      icon: const Icon(Icons.tune_rounded),
                      tooltip: 'Editar perfil tienda',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              if (store.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  store.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (isOwnProfile) ...[
                const SizedBox(height: 14),
                const _StoreInfoBox(
                  text:
                      'Agregá una descripción para contar qué vendés y cómo trabajás.',
                ),
              ],
              const SizedBox(height: 14),
              _StoreStatsRow(
                postsLabel: postsLabel,
                followersLabel: followersLabel,
                savesLabel: savesLabel,
                viewsLabel: _compact(store.profileViews),
              ),
              if (store.categories.isNotEmpty) ...[
                const SizedBox(height: 14),
                _StorePillSection(
                  title: 'Categorías',
                  values: store.categories,
                ),
              ],
              if (store.deliveryMethods.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StorePillSection(
                  title: 'Entregas',
                  values: store.deliveryMethods,
                ),
              ],
              if (store.paymentMethods.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StorePillSection(
                  title: 'Pagos informativos',
                  values: store.paymentMethods,
                ),
              ],
              if (store.openingHours.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _StoreInfoBox(text: 'Horario: ${store.openingHours}'),
              ],
              const SizedBox(height: 14),
              const _StoreInfoBox(
                text:
                    'Compra segura: hablá por mensaje, revisá referencias y no compartas datos sensibles fuera de canales confiables.',
              ),
              const SizedBox(height: 14),
              if (isOwnProfile)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar perfil tienda'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busyFollow ? null : onFollow,
                        icon: Icon(
                          following
                              ? Icons.check_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                        label: Text(following ? 'Siguiendo' : 'Seguir tienda'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onMessage,
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Mensaje'),
                      ),
                    ),
                    if (onReport != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onReport,
                        icon: const Icon(Icons.flag_outlined),
                        tooltip: 'Reportar tienda',
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _statusColor(StoreProfileStatus status) {
    return switch (status) {
      StoreProfileStatus.active => AppTheme.teal,
      StoreProfileStatus.pending => AppTheme.amber,
      StoreProfileStatus.paused => AppTheme.violet,
      StoreProfileStatus.blocked => AppTheme.rose,
    };
  }

  static String _storeLocation(StoreProfile store) {
    final parts = [
      if (store.city.trim().isNotEmpty) store.city.trim(),
      if (store.region.trim().isNotEmpty &&
          store.region.trim() != store.city.trim())
        store.region.trim(),
      if (store.country.trim().isNotEmpty) store.country.trim(),
    ];
    return parts.join(', ');
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _StoreStatsRow extends StatelessWidget {
  const _StoreStatsRow({
    required this.postsLabel,
    required this.followersLabel,
    required this.savesLabel,
    required this.viewsLabel,
  });

  final String postsLabel;
  final String followersLabel;
  final String savesLabel;
  final String viewsLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StoreStat(value: postsLabel, label: 'posts'),
        ),
        Expanded(
          child: _StoreStat(value: followersLabel, label: 'seguidores'),
        ),
        Expanded(
          child: _StoreStat(value: savesLabel, label: 'guardados'),
        ),
        Expanded(
          child: _StoreStat(value: viewsLabel, label: 'visitas'),
        ),
      ],
    );
  }
}

class _StoreStat extends StatelessWidget {
  const _StoreStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorePillSection extends StatelessWidget {
  const _StorePillSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final value in values)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.violet.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  storeOptionLabel(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StoreBadge extends StatelessWidget {
  const _StoreBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreInfoBox extends StatelessWidget {
  const _StoreInfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          height: 1.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
