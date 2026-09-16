import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'hub_avatar.dart';
import 'shared_news_post_card.dart';
import 'post_video_player.dart';
import 'story_canvas.dart';

class HallyuPostCard extends StatelessWidget {
  const HallyuPostCard({
    super.key,
    required this.post,
    required this.liked,
    required this.saved,
    required this.shared,
    required this.likesLabel,
    required this.commentsLabel,
    required this.sharesLabel,
    required this.savesLabel,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.onOpenProfile,
    this.onOpenTaggedPerson,
    this.onOpenTaggedEntity,
    this.onOpenNews,
    this.onMore,
    this.videosMuted = true,
    this.onToggleVideoSound,
    this.secondaryLabel,
    this.bottomPadding = 26,
  });

  final HubPost post;
  final bool liked;
  final bool saved;
  final bool shared;
  final String likesLabel;
  final String commentsLabel;
  final String sharesLabel;
  final String savesLabel;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback? onOpenProfile;
  final ValueChanged<String>? onOpenTaggedPerson;
  final ValueChanged<KpopEntity>? onOpenTaggedEntity;
  final ValueChanged<String>? onOpenNews;
  final VoidCallback? onMore;
  final bool videosMuted;
  final VoidCallback? onToggleVideoSound;
  final String? secondaryLabel;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final isLive = post.mood == 'En vivo';
    final displayName = _postDisplayName(post);
    final parsedNewsPost = SharedNewsPostContent.fromCaption(post.caption);
    final newsContent = parsedNewsPost.news;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 2, 10),
              child: Row(
                children: [
                  Semantics(
                    label: 'Abrir perfil de ${post.author}',
                    button: onOpenProfile != null,
                    child: GestureDetector(
                      onTap: onOpenProfile,
                      behavior: HitTestBehavior.opaque,
                      child: HubAvatar(
                        asset: post.avatarAsset,
                        size: 44,
                        isLive: isLive,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: GestureDetector(
                      onTap: onOpenProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.54),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppTheme.violet.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              IgnorePointer(child: _PostKindBadge(post)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onMore != null)
                    IconButton(
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: Colors.white,
                      tooltip: 'Más opciones',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                ],
              ),
            ),
            if (newsContent != null)
              SharedNewsPostCard(
                key: ValueKey('shared-news-card-${post.id}'),
                news: newsContent,
                onOpen: onOpenNews,
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _HallyuPostMediaStage(
                  post: post,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _HallyuPostMedia(
                        key: ValueKey('post-media-${post.id}'),
                        post: post,
                        muted: videosMuted,
                      ),
                      const _HallyuPostMediaShade(),
                      if (post.hasVideoMedia && onToggleVideoSound != null)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: IconButton.filled(
                            key: ValueKey('post-sound-${post.id}'),
                            onPressed: onToggleVideoSound,
                            icon: Icon(
                              videosMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                            ),
                            tooltip: videosMuted
                                ? 'Activar audio en todos los videos'
                                : 'Silenciar todos los videos',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.56,
                              ),
                              foregroundColor: Colors.white,
                              fixedSize: const Size(40, 40),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 5),
            _HallyuPostGlassActionBar(
              children: [
                _HallyuPostAction(
                  key: ValueKey('like-${post.id}'),
                  icon: liked ? Icons.star_rounded : Icons.star_border_rounded,
                  label: likesLabel,
                  color: AppTheme.violet,
                  active: liked,
                  semanticLabel: 'Dar estrella a ${post.author}',
                  onTap: onLike,
                ),
                _HallyuPostAction(
                  key: ValueKey('comment-${post.id}'),
                  icon: Icons.chat_bubble_outline_rounded,
                  label: commentsLabel,
                  color: AppTheme.cyan,
                  semanticLabel: 'Comentar post de ${post.author}',
                  onTap: onComment,
                ),
                _HallyuPostAction(
                  key: ValueKey('share-${post.id}'),
                  icon: shared ? Icons.near_me_rounded : Icons.near_me_outlined,
                  label: sharesLabel,
                  color: AppTheme.rose,
                  active: shared,
                  semanticLabel: 'Compartir post de ${post.author}',
                  onTap: onShare,
                ),
                _HallyuPostAction(
                  key: ValueKey('save-${post.id}'),
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: savesLabel,
                  color: AppTheme.violet,
                  active: saved,
                  semanticLabel: 'Guardar post de ${post.author}',
                  onTap: onSave,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 7, 4, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (newsContent == null || parsedNewsPost.comment.isNotEmpty)
                    _ExpandableHallyuPostCaption(
                      post: post,
                      caption: parsedNewsPost.comment,
                    ),
                  if (secondaryLabel?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      secondaryLabel!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (commentsLabel != '0') ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onComment,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        commentsLabel == '1'
                            ? 'Ver 1 comentario'
                            : 'Ver los $commentsLabel comentarios',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  if (post.taggedPeople.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    _TaggedPeopleRow(
                      usernames: post.taggedPeople,
                      onOpen: onOpenTaggedPerson,
                    ),
                  ],
                  if (post.taggedEntities.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    _TaggedEntityRow(
                      entities: post.taggedEntities,
                      onOpen: onOpenTaggedEntity,
                    ),
                  ],
                  if (post.location.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppTheme.cyan.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.tags.map(_HallyuHashtagChip.new).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _postDisplayName(HubPost post) {
  final username = post.username.trim();
  if (username.isNotEmpty) return username.replaceFirst('@', '');
  return post.author;
}

class _HallyuPostMediaShade extends StatelessWidget {
  const _HallyuPostMediaShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.18),
            ],
            stops: const [0, 0.24, 0.76, 1],
          ),
        ),
      ),
    );
  }
}

class _HallyuPostMediaStage extends StatelessWidget {
  const _HallyuPostMediaStage({required this.post, required this.child});

  final HubPost post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewport.width;
        final maxHeight = math.min(
          math.max(viewport.height * 0.7, 320.0),
          620.0,
        );
        final preferredHeight = post.hasVideoMedia ? width / (9 / 16) : width;
        final height = math.min(math.max(preferredHeight, 280.0), maxHeight);

        return SizedBox(width: double.infinity, height: height, child: child);
      },
    );
  }
}

class _PostKindBadge extends StatelessWidget {
  const _PostKindBadge(this.post);

  final HubPost post;

  @override
  Widget build(BuildContext context) {
    final label = post.hasCarousel
        ? '${post.effectiveMediaItems.length} fotos'
        : post.hasVideoMedia
        ? 'Video'
        : 'Post';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HallyuPostGlassActionBar extends StatelessWidget {
  const _HallyuPostGlassActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final leading = children.length > 1
        ? children.take(children.length - 1).toList(growable: false)
        : children;
    final trailing = children.length > 1
        ? <Widget>[children.last]
        : const <Widget>[];
    return SizedBox(
      height: 50,
      child: Row(children: [...leading, const Spacer(), ...trailing]),
    );
  }
}

class _HallyuPostAction extends StatelessWidget {
  const _HallyuPostAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active ? color : Colors.white.withValues(alpha: 0.92),
                size: 27,
              ),
              if (label != '0') const SizedBox(width: 7),
              if (label != '0')
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HallyuPostMedia extends StatefulWidget {
  const _HallyuPostMedia({super.key, required this.post, required this.muted});

  final HubPost post;
  final bool muted;

  @override
  State<_HallyuPostMedia> createState() => _HallyuPostMediaState();
}

class _HallyuPostMediaState extends State<_HallyuPostMedia> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _HallyuPostMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItems = oldWidget.post.effectiveMediaItems;
    final newItems = widget.post.effectiveMediaItems;
    final changedPost = oldWidget.post.id != widget.post.id;
    final changedMedia =
        oldItems.length != newItems.length ||
        List.generate(
          math.min(oldItems.length, newItems.length),
          (index) => oldItems[index].id != newItems[index].id,
        ).any((changed) => changed);
    if (!changedPost && !changedMedia) return;

    _activeIndex = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final items = post.effectiveMediaItems;
    const filterColors = <Color>[
      Colors.transparent,
      Color(0x26EF4F7A),
      Color(0x2439E6E6),
      Color(0x24A855F7),
    ];
    if (items.isEmpty) {
      return const _HallyuMediaFallback();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
            scrollbars: false,
          ),
          child: PageView.builder(
            key: PageStorageKey<String>('post-media-carousel-${post.id}'),
            controller: _pageController,
            physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
            itemCount: items.length,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) {
              final item = items[index];
              return Semantics(
                key: ValueKey('post-media-${post.id}-${item.id}-$index'),
                image: !item.isVideo,
                label: item.isVideo
                    ? 'Video ${index + 1} de ${items.length}'
                    : 'Foto ${index + 1} de ${items.length}',
                child: RepaintBoundary(
                  child: item.isVideo
                      ? PostVideoPlayer(
                          path: item.mediaPath.isNotEmpty
                              ? item.mediaPath
                              : item.imageAsset,
                          muted: widget.muted,
                          trimStartSeconds: item.videoTrimStartSeconds,
                          trimEndSeconds: item.videoTrimEndSeconds,
                          fit: BoxFit.cover,
                        )
                      : StoryCanvas(
                          contentType: StoryContentType.image,
                          imageAsset: item.imageAsset,
                          imageBytes: item.imageBytes,
                          mediaPath: item.mediaPath,
                          backgroundColors: const [
                            Color(0xFF050711),
                            AppTheme.nightSoft,
                          ],
                          elements: post.elements,
                          mediaScale: item.mediaScale,
                          mediaOffset: item.mediaOffset,
                          mediaRotation: item.mediaRotation,
                          visualFilter: StoryVisualFilter.original,
                          mediaFit: BoxFit.contain,
                        ),
                ),
              );
            },
          ),
        ),
        if (post.filterIndex > 0 && post.filterIndex < filterColors.length)
          IgnorePointer(
            child: ColoredBox(color: filterColors[post.filterIndex]),
          ),
        if (items.length > 1) ...[
          Positioned(
            right: 12,
            top: 12,
            child: IgnorePointer(
              child: _PostCarouselPill(
                key: ValueKey('post-carousel-pill-${post.id}'),
                current: _activeIndex + 1,
                total: items.length,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: IgnorePointer(
              child: _PostCarouselDots(
                key: ValueKey('post-carousel-dots-${post.id}'),
                count: items.length,
                activeIndex: _activeIndex,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HallyuMediaFallback extends StatelessWidget {
  const _HallyuMediaFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.nightSoft, AppTheme.violet]),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white70, size: 42),
      ),
    );
  }
}

class _PostCarouselPill extends StatelessWidget {
  const _PostCarouselPill({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$current/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PostCarouselDots extends StatelessWidget {
  const _PostCarouselDots({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: active
                ? const LinearGradient(colors: [AppTheme.rose, AppTheme.cyan])
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.42),
          ),
        );
      }),
    );
  }
}

class _ExpandableHallyuPostCaption extends StatefulWidget {
  const _ExpandableHallyuPostCaption({required this.post, this.caption});

  final HubPost post;
  final String? caption;

  @override
  State<_ExpandableHallyuPostCaption> createState() =>
      _ExpandableHallyuPostCaptionState();
}

class _ExpandableHallyuPostCaptionState
    extends State<_ExpandableHallyuPostCaption> {
  bool _expanded = false;

  bool get _canExpand => _caption.length > 105;

  String get _caption {
    final text = (widget.caption ?? widget.post.caption).trim();
    if (text.isNotEmpty) return text;
    return 'Publicación de ${widget.post.author}';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final displayName = _postDisplayName(post);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$displayName ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: _caption,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          key: ValueKey('post-caption-${post.id}'),
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15.5, height: 1.34),
        ),
        if (_canExpand)
          TextButton(
            key: ValueKey('post-caption-toggle-${post.id}'),
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.62),
              minimumSize: const Size(0, 24),
              padding: const EdgeInsets.only(top: 3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Ver menos' : 'Ver más',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

class _TaggedPeopleRow extends StatelessWidget {
  const _TaggedPeopleRow({required this.usernames, required this.onOpen});

  final List<String> usernames;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final cleaned = usernames
        .map((username) => username.trim())
        .where((username) => username.isNotEmpty)
        .map((username) => username.startsWith('@') ? username : '@$username')
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) return const SizedBox.shrink();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Text(
          'Con',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .68),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        ...cleaned.map(
          (username) => InkWell(
            onTap: onOpen == null ? null : () => onOpen!(username),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.cyan.withValues(alpha: .32)),
              ),
              child: Text(
                username,
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaggedEntityRow extends StatelessWidget {
  const _TaggedEntityRow({required this.entities, required this.onOpen});

  final List<KpopEntity> entities;
  final ValueChanged<KpopEntity>? onOpen;

  @override
  Widget build(BuildContext context) {
    final cleaned = <String, KpopEntity>{};
    for (final entity in entities) {
      if (entity.id.trim().isEmpty || entity.name.trim().isEmpty) continue;
      cleaned.putIfAbsent(entity.id, () => entity);
    }
    if (cleaned.isEmpty) return const SizedBox.shrink();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Text(
          'Etiquetado',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .68),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        ...cleaned.values.map(
          (entity) => InkWell(
            onTap: onOpen == null ? null : () => onOpen!(entity),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.rose.withValues(alpha: .22),
                    AppTheme.cyan.withValues(alpha: .18),
                    AppTheme.violet.withValues(alpha: .22),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.rose.withValues(alpha: .28)),
              ),
              child: Text(
                entity.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HallyuHashtagChip extends StatelessWidget {
  const _HallyuHashtagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.indigo.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
