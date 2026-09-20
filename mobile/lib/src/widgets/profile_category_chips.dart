import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'premium_profile_visuals.dart';

class ProfileCategorySelector extends StatelessWidget {
  const ProfileCategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<ProfileContentCategory> selected;
  final ValueChanged<Set<ProfileContentCategory>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guardá este contenido en tu perfil',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Elegí hasta 5 categorías. Es opcional.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in ProfileContentCategory.values)
                _SelectableCategoryChip(
                  category: category,
                  selected: selected.contains(category),
                  onTap: () => _toggle(category, context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggle(ProfileContentCategory category, BuildContext context) {
    final next = {...selected};
    if (next.contains(category)) {
      next.remove(category);
    } else {
      if (next.length >= 5) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Elegí hasta 5 categorías por contenido.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      next.add(category);
    }
    onChanged(next);
  }
}

class ProfileCategoryRail extends StatelessWidget {
  const ProfileCategoryRail({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final Map<ProfileContentCategory, int> counts;
  final ProfileContentCategory? selected;
  final ValueChanged<ProfileContentCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileVisualSectionHeader(
          title: 'Destacados',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: ProfileContentCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = ProfileContentCategory.values[index];
              final count = counts[category] ?? 0;
              final isSelected = selected == category;
              final label = category == ProfileContentCategory.collection
                  ? 'Colección+'
                  : category.label;
              return InkWell(
                key: ValueKey('profile-highlight-${category.label}'),
                onTap: () => onSelected(isSelected ? null : category),
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 82,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _categoryColors(category),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: isSelected ? 0.8 : 0.25,
                                ),
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _categoryColors(category).first
                                      .withValues(
                                        alpha: isSelected ? 0.4 : 0.18,
                                      ),
                                  blurRadius: isSelected ? 22 : 14,
                                ),
                              ],
                            ),
                            child: Icon(
                              _categoryIcon(category),
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 23),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.night,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: isSelected ? 1 : 0.8,
                          ),
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PremiumProfileHighlights extends StatelessWidget {
  const PremiumProfileHighlights({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
    this.onTopKpop,
  });

  final Map<ProfileContentCategory, int> counts;
  final ProfileContentCategory? selected;
  final ValueChanged<ProfileContentCategory?> onSelected;
  final VoidCallback? onTopKpop;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (onTopKpop != null) _PremiumTopKpopHighlight(onTap: onTopKpop!),
      for (final category in const [
        ProfileContentCategory.concerts,
        ProfileContentCategory.bias,
        ProfileContentCategory.photocards,
        ProfileContentCategory.outfit,
      ])
        _PremiumHighlightCard(
          category: category,
          count: counts[category] ?? 0,
          selected: selected == category,
          onTap: () => onSelected(selected == category ? null : category),
        ),
      _PremiumHighlightCard(
        category: ProfileContentCategory.other,
        displayLabel: 'Stage',
        displaySubtitle: 'Momentos inolvidables',
        displayAsset: 'assets/brand/hally_discover_groups_stage_v2.jpg',
        displayIcon: Icons.theater_comedy_rounded,
        count: 0,
        selected: false,
        onTap: () => onSelected(ProfileContentCategory.other),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileVisualSectionHeader(
          title: 'Destacados',
          icon: Icons.auto_awesome_rounded,
          subtitle: 'Explora mis temáticas favoritas',
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => cards[index],
          ),
        ),
      ],
    );
  }
}

class _PremiumTopKpopHighlight extends StatelessWidget {
  const _PremiumTopKpopHighlight({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Top K-pop',
      child: InkWell(
        key: const ValueKey('profile-highlight-Top K-pop'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 154,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cyan.withValues(alpha: .75)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cyan.withValues(alpha: .18),
                blurRadius: 16,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/brand/hally_explore_kpop101_card_v1.png',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .08),
                        Colors.black.withValues(alpha: .88),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(11, 10, 9, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.violet,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Top K-pop',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tendencias del momento',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  right: 9,
                  bottom: 10,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumHighlightCard extends StatelessWidget {
  const _PremiumHighlightCard({
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
    this.displayLabel,
    this.displaySubtitle,
    this.displayAsset,
    this.displayIcon,
  });

  final ProfileContentCategory category;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final String? displayLabel;
  final String? displaySubtitle;
  final String? displayAsset;
  final IconData? displayIcon;

  static const _assets = {
    ProfileContentCategory.concerts:
        'assets/brand/hally_discover_events_v2.jpg',
    ProfileContentCategory.other:
        'assets/brand/hally_discover_neon_backdrop_v1.jpg',
  };

  static const _subtitles = {
    ProfileContentCategory.concerts: 'Fechas, giras y más',
    ProfileContentCategory.bias: 'Tus favoritos siempre aquí',
    ProfileContentCategory.photocards: 'Colecciona la magia',
    ProfileContentCategory.outfit: 'Estilo K-pop sin límites',
    ProfileContentCategory.collection: 'Tu colección',
    ProfileContentCategory.trades: 'Para intercambiar',
    ProfileContentCategory.merch: 'Objetos de fan',
    ProfileContentCategory.fanart: 'Arte de la comunidad',
    ProfileContentCategory.other: 'Más historias',
  };

  @override
  Widget build(BuildContext context) {
    final colors = _categoryColors(category);
    final label = displayLabel ?? category.label;
    final subtitle = displaySubtitle ?? _subtitles[category]!;
    final asset = displayAsset ?? _assets[category];
    final icon = displayIcon ?? _categoryIcon(category);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 154,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : colors.last.withValues(alpha: .7),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: .18),
                blurRadius: 16,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (asset != null)
                  Image.asset(asset, fit: BoxFit.cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.first.withValues(alpha: .42),
                          AppTheme.night,
                          colors.last.withValues(alpha: .22),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 88,
                        color: colors.last.withValues(alpha: .18),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .08),
                        Colors.black.withValues(alpha: .34),
                        Colors.black.withValues(alpha: .9),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 9, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.first.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .76),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '$count',
                          style: TextStyle(
                            color: colors.last,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
                const Positioned(
                  right: 9,
                  bottom: 10,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectableCategoryChip extends StatelessWidget {
  const _SelectableCategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ProfileContentCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? LinearGradient(colors: _categoryColors(category))
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.07),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _categoryIcon(category),
              size: 16,
              color: selected ? AppTheme.night : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                color: selected ? AppTheme.night : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(ProfileContentCategory category) {
  return switch (category) {
    ProfileContentCategory.concerts => Icons.confirmation_num_outlined,
    ProfileContentCategory.bias => Icons.favorite_rounded,
    ProfileContentCategory.photocards => Icons.style_rounded,
    ProfileContentCategory.outfit => Icons.checkroom_outlined,
    ProfileContentCategory.collection => Icons.collections_bookmark_outlined,
    ProfileContentCategory.trades => Icons.swap_horiz_rounded,
    ProfileContentCategory.merch => Icons.shopping_bag_outlined,
    ProfileContentCategory.fanart => Icons.brush_outlined,
    ProfileContentCategory.other => Icons.auto_awesome_rounded,
  };
}

List<Color> _categoryColors(ProfileContentCategory category) {
  return switch (category) {
    ProfileContentCategory.concerts => const [AppTheme.rose, AppTheme.violet],
    ProfileContentCategory.bias => const [AppTheme.amber, AppTheme.rose],
    ProfileContentCategory.photocards => const [AppTheme.teal, AppTheme.cyan],
    ProfileContentCategory.outfit => const [AppTheme.rose, AppTheme.amber],
    ProfileContentCategory.collection => const [AppTheme.cyan, AppTheme.violet],
    ProfileContentCategory.trades => const [AppTheme.amber, AppTheme.cyan],
    ProfileContentCategory.merch => const [AppTheme.indigo, AppTheme.rose],
    ProfileContentCategory.fanart => const [AppTheme.violet, AppTheme.rose],
    ProfileContentCategory.other => const [AppTheme.nightSoft, AppTheme.cyan],
  };
}
