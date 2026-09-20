import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/repost_service.dart';
import '../services/share_links.dart';
import '../theme/app_theme.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/hallyu_post_card.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/share_sheet.dart';

/// Outfit is intentionally a Posts category. The screen does not introduce
/// a parallel content model or media service.
class OutfitScreen extends StatefulWidget {
  const OutfitScreen({
    super.key,
    required this.postService,
    this.user,
    this.repostService,
    this.safetyService = const LocalSafetyService(),
    this.onCreateOutfit,
  });

  final LocalPostService postService;
  final AuthUser? user;
  final RepostService? repostService;
  final LocalSafetyService safetyService;
  final Future<void> Function()? onCreateOutfit;

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

enum _OutfitMode { forYou, popular, following }

class _OutfitScreenState extends State<OutfitScreen> {
  _OutfitMode _mode = _OutfitMode.forYou;
  String _category = 'all';
  final List<OutfitFeedItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;

  static const _pageSize = 24;
  static const _categories = <String, String>{
    'all': 'Todos',
    'stage': 'Stage',
    'airport': 'Airport',
    'casual': 'Casual',
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
        _items.clear();
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await widget.postService.restoreOutfitFeed(
        mode: switch (_mode) {
          _OutfitMode.forYou => OutfitFeedMode.forYou,
          _OutfitMode.popular => OutfitFeedMode.popular,
          _OutfitMode.following => OutfitFeedMode.following,
        },
        category: _category,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      final existing = _items.map((item) => item.post.id).toSet();
      final fresh = page.where((item) => existing.add(item.post.id)).toList();
      setState(() {
        _items.addAll(fresh);
        _offset += page.length;
        _hasMore = page.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'No pudimos cargar los Outfits. Probá otra vez.';
      });
    }
  }

  void _setMode(_OutfitMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _load(reset: true);
  }

  void _setCategory(String category) {
    if (_category == category) return;
    setState(() => _category = category);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        title: const Text('Outfits'),
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 560.0);
          const columns = 2;
          const spacing = 10.0;
          return Center(
            child: SizedBox(
              width: width,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 500) {
                    _load(reset: false);
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  color: AppTheme.cyan,
                  child: CustomScrollView(
                    key: const ValueKey('outfit-scroll'),
                    slivers: [
                      SliverToBoxAdapter(child: _buildModeSelector()),
                      SliverToBoxAdapter(child: _buildCategorySelector()),
                      if (_loading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ErrorState(
                            message: _error!,
                            onRetry: () => _load(reset: true),
                          ),
                        )
                      else if (_items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyOutfitState(
                            onCreate: widget.onCreateOutfit == null
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await widget.onCreateOutfit!.call();
                                  },
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == _items.length) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final item = _items[index];
                                return _OutfitCard(
                                  key: ValueKey('outfit-card-${item.post.id}'),
                                  item: item,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => _OutfitPostDetailScreen(
                                        item: item,
                                        postService: widget.postService,
                                        user: widget.user,
                                        repostService: widget.repostService,
                                        safetyService: widget.safetyService,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount:
                                  _items.length + (_loadingMore ? 1 : 0),
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                  childAspectRatio: 0.70,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeSelector() {
    return _SelectorRow<_OutfitMode>(
      key: const ValueKey('outfit-mode-selector'),
      values: const {
        _OutfitMode.forYou: 'Para ti',
        _OutfitMode.popular: 'Más populares',
        _OutfitMode.following: 'Siguiendo',
      },
      selected: _mode,
      onSelected: _setMode,
      semanticPrefix: 'Modo de Outfits',
    );
  }

  Widget _buildCategorySelector() {
    return _SelectorRow<String>(
      key: const ValueKey('outfit-category-selector'),
      values: _categories,
      selected: _category,
      onSelected: _setCategory,
      semanticPrefix: 'Categoría de Outfit',
    );
  }
}

class _SelectorRow<T> extends StatelessWidget {
  const _SelectorRow({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
    required this.semanticPrefix,
  });

  final Map<T, String> values;
  final T selected;
  final ValueChanged<T> onSelected;
  final String semanticPrefix;

  @override
  Widget build(BuildContext context) {
    final isCategory = semanticPrefix == 'Categoría de Outfit';
    return Padding(
      padding: EdgeInsets.fromLTRB(14, isCategory ? 2 : 5, 14, 3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: values.entries.map((entry) {
            final active = entry.key == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: active,
                label: '$semanticPrefix ${entry.value}',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [AppTheme.violet, AppTheme.rose],
                          )
                        : null,
                    color: active
                        ? null
                        : AppTheme.panel.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? AppTheme.cyan.withValues(alpha: 0.65)
                          : AppTheme.stroke.withValues(alpha: 0.7),
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('$semanticPrefix-${entry.key}'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelected(entry.key),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCategory ? 11 : 14,
                        vertical: isCategory ? 6 : 8,
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontSize: isCategory ? 12 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({super.key, required this.item, required this.onTap});

  final OutfitFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final media = post.effectiveMediaItems.firstOrNull;
    final category = _categoryLabel(item.categoryKey);
    final entity = post.artist.isNotEmpty
        ? post.artist
        : post.taggedEntities.map((e) => e.name).join(' · ');
    return Semantics(
      button: true,
      label: 'Abrir Outfit de ${post.author}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.violet.withValues(alpha: 0.48)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OutfitMedia(post: post, media: media),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HubAvatar(asset: post.avatarAsset, size: 24),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            post.username.isEmpty ? post.author : post.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _SmallPill(label: category),
                      ],
                    ),
                    if (entity.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        entity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_border_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          post.likes,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 9),
                        const Icon(
                          Icons.bookmark_border_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          post.saves,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (item.hasRepostMetadata) ...[
                          const Spacer(),
                          const Icon(
                            Icons.repeat_rounded,
                            size: 15,
                            color: AppTheme.rose,
                          ),
                        ],
                      ],
                    ),
                    if (item.hasRepostMetadata)
                      Text(
                        'Reposteado por ${item.repostedByUsername}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.rose,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOutfitState extends StatelessWidget {
  const _EmptyOutfitState({required this.onCreate});

  final Future<void> Function()? onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.panel.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.violet.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.violet, AppTheme.rose],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.violet.withValues(alpha: 0.28),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(
                    Icons.checkroom_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Todavía no hay outfits para mostrar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sé de los primeros en compartir un look',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (onCreate != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear Outfit'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _OutfitMedia extends StatelessWidget {
  const _OutfitMedia({required this.post, required this.media});

  final HubPost post;
  final PostMediaItem? media;

  @override
  Widget build(BuildContext context) {
    final bytes = media?.imageBytes ?? post.imageBytes;
    final path = media?.mediaPath.isNotEmpty == true
        ? media!.mediaPath
        : media?.imageAsset.isNotEmpty == true
        ? media!.imageAsset
        : post.mediaPath.isNotEmpty
        ? post.mediaPath
        : post.imageAsset;
    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover);
    } else if (path.startsWith('http')) {
      image = Image.network(path, fit: BoxFit.cover);
    } else if (path.isNotEmpty) {
      image = Image.asset(path, fit: BoxFit.cover);
    } else {
      image = const Center(child: Icon(Icons.checkroom_rounded, size: 44));
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SizedBox(width: double.infinity, child: image),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.violet.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white70, fontSize: 10),
    ),
  );
}

String _categoryLabel(String key) => switch (key) {
  'outfit_stage' => 'Stage',
  'outfit_airport' => 'Airport',
  'outfit_casual' => 'Casual',
  _ => 'Outfit',
};

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(message),
      const SizedBox(height: 12),
      FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
    ],
  );
}

class _OutfitPostDetailScreen extends StatefulWidget {
  const _OutfitPostDetailScreen({
    required this.item,
    required this.postService,
    required this.user,
    required this.repostService,
    required this.safetyService,
  });

  final OutfitFeedItem item;
  final LocalPostService postService;
  final AuthUser? user;
  final RepostService? repostService;
  final LocalSafetyService safetyService;

  @override
  State<_OutfitPostDetailScreen> createState() =>
      _OutfitPostDetailScreenState();
}

class _OutfitPostDetailScreenState extends State<_OutfitPostDetailScreen> {
  late bool _liked = widget.item.post.likedByCurrentUser;
  late bool _saved = widget.item.post.savedByCurrentUser;
  bool _reposted = false;
  bool _busyRepost = false;

  @override
  void initState() {
    super.initState();
    _loadRepostState();
  }

  Future<void> _loadRepostState() async {
    final service = widget.repostService;
    if (service == null) return;
    final value = await service.hasReposted(
      contentType: RepostContentType.post,
      contentId: widget.item.post.id,
    );
    if (mounted) setState(() => _reposted = value);
  }

  Future<void> _toggleRepost() async {
    final service = widget.repostService;
    if (service == null || _busyRepost) return;
    final next = !_reposted;
    setState(() {
      _busyRepost = true;
      _reposted = next;
    });
    try {
      if (next) {
        await service.createRepost(
          contentType: RepostContentType.post,
          contentId: widget.item.post.id,
        );
      } else {
        await service.removeRepost(
          contentType: RepostContentType.post,
          contentId: widget.item.post.id,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _reposted = !next);
    } finally {
      if (mounted) setState(() => _busyRepost = false);
    }
  }

  Future<void> _openComments() async {
    final post = widget.item.post;
    final comments = await widget.postService.restoreComments(post.id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        threadId: post.id,
        subtitle: post.author,
        initialComments: comments,
        currentUserName: widget.user?.name ?? 'Tu perfil',
        currentUsername: widget.user?.username ?? '@mika.hallyu',
        currentUserAvatar: widget.user?.avatarAsset ?? '',
        safetyService: widget.safetyService,
        onChanged: (_) {},
        onCommentAdded: () {},
        onSubmitComment: widget.user == null
            ? null
            : (body, parentId) => widget.postService.addComment(
                author: widget.user!,
                postId: post.id,
                body: body,
                parentId: parentId,
              ),
        onDeleteComment: (comment) => widget.postService.deleteComment(
          postId: post.id,
          commentId: comment.id,
        ),
      ),
    );
  }

  void _openShare() {
    final post = widget.item.post;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AppShareSheet(
        title: 'Compartir Outfit',
        subtitle: post.caption,
        shareText: '${post.caption}\n${ShareLinks.publication(post.id)}',
        recipients: const [],
        onSelected: (message) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            this.context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.item.post;
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(title: const Text('Outfit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: HallyuPostCard(
          post: post,
          liked: _liked,
          saved: _saved,
          shared: false,
          likesLabel: post.likes,
          commentsLabel: post.comments,
          sharesLabel: post.shares,
          savesLabel: post.saves,
          onLike: () async {
            final next = !_liked;
            setState(() => _liked = next);
            try {
              await widget.postService.setPostLiked(post.id, next);
            } catch (_) {
              if (mounted) setState(() => _liked = !next);
            }
          },
          onComment: _openComments,
          onShare: _openShare,
          onSave: () async {
            final next = !_saved;
            setState(() => _saved = next);
            try {
              await widget.postService.setPostSaved(post.id, next);
            } catch (_) {
              if (mounted) setState(() => _saved = !next);
            }
          },
          onRepost: widget.repostService == null ? null : _toggleRepost,
          reposted: _reposted,
          bottomPadding: 12,
          secondaryLabel: widget.item.hasRepostMetadata
              ? 'Reposteado por ${widget.item.repostedByUsername}'
              : null,
        ),
      ),
    );
  }
}
