import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfileFeatureItem {
  const ProfileFeatureItem({
    required this.id,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.previews = const [],
  });

  final String id;
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final List<Widget> previews;
}

class PremiumProfileFeatureDeck extends StatelessWidget {
  const PremiumProfileFeatureDeck({super.key, required this.items, this.title});

  final String? title;
  final List<ProfileFeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.trim().isNotEmpty) ...[
          ProfileVisualSectionHeader(
            title: title!,
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              final cardWidth = (constraints.maxWidth * 0.4)
                  .clamp(142.0, 178.0)
                  .toDouble();
              return SizedBox(
                height: 174,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 4),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemCount: items.length,
                  itemBuilder: (context, index) => SizedBox(
                    width: cardWidth,
                    child: _ProfileFeatureCard(item: items[index]),
                  ),
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  Expanded(child: _ProfileFeatureCard(item: items[index])),
                  if (index != items.length - 1) const SizedBox(width: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class ProfileVisualSectionHeader extends StatelessWidget {
  const ProfileVisualSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.rose.withValues(alpha: 0.9),
                AppTheme.violet.withValues(alpha: 0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.rose.withValues(alpha: 0.2),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .58),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _ProfileFeatureCard extends StatelessWidget {
  const _ProfileFeatureCard({required this.item});

  final ProfileFeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('profile-feature-${item.id}'),
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 174,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF111522),
                item.colors.first.withValues(alpha: 0.11),
                const Color(0xFF070A12),
              ],
            ),
            border: Border.all(color: item.colors.last.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: item.colors.first.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -28,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        item.colors.last.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -12,
                right: -12,
                bottom: -12,
                height: 78,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.colors.first.withValues(alpha: 0.12),
                        item.colors.last.withValues(alpha: 0.34),
                        AppTheme.night.withValues(alpha: 0.96),
                      ],
                    ),
                    border: Border(
                      top: BorderSide(
                        color: item.colors.last.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: item.colors),
                          boxShadow: [
                            BoxShadow(
                              color: item.colors.first.withValues(alpha: 0.25),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.value,
                          style: TextStyle(
                            color: item.colors.last,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: ' ${item.detail}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (item.previews.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < item.previews.length && index < 3;
                            index++
                          )
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < item.previews.length - 1
                                      ? 3
                                      : 0,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: item.previews[index],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [
                            item.colors.first.withValues(alpha: 0.13),
                            item.colors.last.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          item.icon,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
