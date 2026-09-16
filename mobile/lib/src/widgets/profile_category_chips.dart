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
