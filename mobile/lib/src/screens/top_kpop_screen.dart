import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import '../services/kpop_entity_follow_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/local_safety_service.dart';
import '../services/store_profile_service.dart';
import '../services/top_kpop_service.dart';
import '../theme/app_theme.dart';
import 'kpop_entity_profile_screen.dart';

class TopKpopScreen extends StatefulWidget {
  const TopKpopScreen({
    super.key,
    required this.user,
    required this.artistTagService,
    required this.postService,
    required this.storyService,
    required this.dropService,
    required this.fancamService,
    required this.followService,
    required this.chatService,
    required this.contentCategoryService,
    required this.userTagService,
    required this.safetyService,
    required this.storeProfileService,
    this.topKpopService,
    this.onFollow,
    this.onOpenEntity,
  });

  final AuthUser user;
  final LocalArtistTagService artistTagService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalFollowService followService;
  final LocalChatService chatService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;
  final TopKpopService? topKpopService;
  final Future<void> Function(TopKpopEntry entry, bool following)? onFollow;
  final ValueChanged<TopKpopEntry>? onOpenEntity;

  @override
  State<TopKpopScreen> createState() => _TopKpopScreenState();
}

class _TopKpopScreenState extends State<TopKpopScreen> {
  static const _pageSize = 20;

  TopKpopType _type = TopKpopType.groups;
  final _scrollController = ScrollController();
  final _items = <TopKpopEntry>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  TopKpopService get _service =>
      widget.topKpopService ?? SupabaseTopKpopService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restore(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 360) _restore();
  }

  Future<void> _restore({bool reset = false}) async {
    if (_loadingMore || (!reset && !_hasMore)) return;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _error = null;
        _items.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await _service.restorePage(
        type: _type,
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('TOP_KPOP_LOAD_ERROR $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'No pudimos cargar el ranking. Probá otra vez.';
      });
    }
  }

  void _selectType(TopKpopType type) {
    if (_type == type) return;
    setState(() => _type = type);
    _restore(reset: true);
  }

  Future<void> _toggleFollow(TopKpopEntry entry) async {
    if (widget.onFollow != null) {
      await widget.onFollow!(entry, !entry.isFollowing);
      return;
    }
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      _showMessage('Iniciá sesión para seguir grupos y artistas.');
      return;
    }
    try {
      await KpopEntityFollowService(client).setFollowing(
        entityId: entry.entityId,
        userId: authUser.id,
        following: !entry.isFollowing,
      );
      if (!mounted) return;
      final index = _items.indexWhere(
        (item) => item.entityId == entry.entityId,
      );
      if (index == -1) return;
      setState(() {
        final delta = entry.isFollowing ? -1 : 1;
        _items[index] = TopKpopEntry(
          entityId: entry.entityId,
          entityType: entry.entityType,
          name: entry.name,
          imageUrl: entry.imageUrl,
          isVerified: entry.isVerified,
          followerCount: entry.followerCount + delta,
          isFollowing: !entry.isFollowing,
        );
      });
    } catch (error) {
      debugPrint('TOP_KPOP_FOLLOW_ERROR ${entry.entityId} $error');
      _showMessage('No pudimos actualizar el seguimiento.');
    }
  }

  void _openEntity(TopKpopEntry entry) {
    if (widget.onOpenEntity != null) {
      widget.onOpenEntity!(entry);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KpopEntityProfileScreen(
          entity: entry.toEntity(),
          currentUser: widget.user,
          artistTagService: widget.artistTagService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          followService: widget.followService,
          chatService: widget.chatService,
          contentCategoryService: widget.contentCategoryService,
          userTagService: widget.userTagService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Top K-pop'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: _TypeTabs(selected: _type, onSelected: _selectType),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.cyan),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        message: _error!,
        action: TextButton(
          onPressed: () => _restore(reset: true),
          child: const Text('Reintentar'),
        ),
      );
    }
    if (_items.isEmpty) {
      return const _MessageState(
        icon: Icons.auto_awesome_rounded,
        message: 'Todavía no hay entidades para mostrar.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.rose,
      onRefresh: () => _restore(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.cyan),
              ),
            );
          }
          final entry = _items[index];
          return _TopKpopRow(
            key: ValueKey(entry.entityId),
            rank: index + 1,
            entry: entry,
            onTap: () => _openEntity(entry),
            onFollow: () => _toggleFollow(entry),
          );
        },
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onSelected});

  final TopKpopType selected;
  final ValueChanged<TopKpopType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tab(TopKpopType.groups, 'Grupos')),
        const SizedBox(width: 10),
        Expanded(child: _tab(TopKpopType.artists, 'Artistas')),
      ],
    );
  }

  Widget _tab(TopKpopType type, String label) {
    final active = selected == type;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        key: ValueKey('top-kpop-tab-${type.name}'),
        onTap: () => onSelected(type),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [AppTheme.violet, AppTheme.rose])
                : null,
            color: active ? null : AppTheme.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? AppTheme.rose : AppTheme.stroke),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: active ? 1 : 0.7),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopKpopRow extends StatelessWidget {
  const _TopKpopRow({
    super.key,
    required this.rank,
    required this.entry,
    required this.onTap,
    required this.onFollow,
  });

  final int rank;
  final TopKpopEntry entry;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final accent = rank <= 3 ? AppTheme.cyan : AppTheme.stroke;
    return Material(
      color: AppTheme.panel.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _EntityAvatar(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCount(entry.followerCount)} seguidores',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onFollow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: entry.isFollowing
                      ? AppTheme.cyan
                      : Colors.white,
                  side: BorderSide(
                    color: entry.isFollowing ? AppTheme.cyan : AppTheme.violet,
                  ),
                  minimumSize: const Size(92, 42),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(entry.isFollowing ? 'Siguiendo' : 'Seguir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityAvatar extends StatelessWidget {
  const _EntityAvatar({required this.entry});

  final TopKpopEntry entry;

  @override
  Widget build(BuildContext context) {
    final imageUrl = entry.imageUrl.trim();
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.violet, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.22),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? const ColoredBox(
                color: AppTheme.nightSoft,
                child: Icon(Icons.groups_rounded, color: AppTheme.cyan),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppTheme.nightSoft,
                  child: Icon(Icons.groups_rounded, color: AppTheme.cyan),
                ),
              ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cyan, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

String _formatCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) {
    return '${(count / 1000).toStringAsFixed(count < 10000 ? 1 : 0)}K';
  }
  return '${(count / 1000000).toStringAsFixed(count < 10000000 ? 1 : 0)}M';
}
