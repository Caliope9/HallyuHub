import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/demo_data.dart';
import '../data/discover_data.dart';
import '../models.dart';
import '../services/local_chat_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/licensed_discover_visual.dart';
import 'fancams_screen.dart';
import 'story_profile_screen.dart';

String _cleanDemoLabel(String value) {
  return value
      .replaceAll(RegExp(r'\bdemo\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            const _DetailAura(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAura extends StatelessWidget {
  const _DetailAura();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -96,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.rose.withValues(alpha: 0.2),
                    AppTheme.violet.withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -124,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.cyan.withValues(alpha: 0.16),
                    AppTheme.teal.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.group,
    this.user,
    this.fancamService = const LocalFancamService(),
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.chatService = const LocalChatService(),
  });

  final DiscoverGroup group;
  final AuthUser? user;
  final LocalFancamService fancamService;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalChatService chatService;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<Fancam> _localFancams = [];
  bool _following = false;

  @override
  void initState() {
    super.initState();
    LocalFancamService.revision.addListener(_restoreLocalFancams);
    _restoreLocalFancams();
  }

  @override
  void dispose() {
    LocalFancamService.revision.removeListener(_restoreLocalFancams);
    super.dispose();
  }

  Future<void> _restoreLocalFancams() async {
    final local = await widget.fancamService.restoreFancams();
    if (!mounted) return;
    setState(() => _localFancams = local);
  }

  void _openIdol(DiscoverIdol idol) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DiscoverPage(
          title: idol.name,
          child: IdolDetailScreen(
            group: widget.group,
            idol: idol,
            user: widget.user,
            fancamService: widget.fancamService,
            followService: widget.followService,
            postService: widget.postService,
            storyService: widget.storyService,
            dropService: widget.dropService,
            chatService: widget.chatService,
          ),
        ),
      ),
    );
  }

  void _openGroupFancams() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DiscoverPage(
          title: '${widget.group.name} · Fancams',
          child: FancamsScreen(
            groupId: widget.group.id,
            title: '${widget.group.name} · Fancams',
            user: widget.user,
            fancamService: widget.fancamService,
            followService: widget.followService,
            postService: widget.postService,
            storyService: widget.storyService,
            dropService: widget.dropService,
            chatService: widget.chatService,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceFancams = widget.fancamService.usesRealFancams
        ? _localFancams
        : [..._localFancams, ...fancams];
    final groupFancams = sourceFancams
        .where((fancam) => fancam.groupId == widget.group.id)
        .toList();
    final groupNews = widget.followService.usesRealProfiles
        ? const <DiscoverNews>[]
        : discoverNews
              .where((item) => item.artist == widget.group.name)
              .toList();
    final groupPosts = widget.postService.usesRealPosts
        ? const <HubPost>[]
        : posts
              .where(
                (post) =>
                    [post.author, post.caption, post.location, ...post.tags]
                        .join(' ')
                        .toLowerCase()
                        .contains(widget.group.name.toLowerCase()) ||
                    post.tags.any(
                      (tag) => tag.toLowerCase().contains(
                        widget.group.fandom.toLowerCase(),
                      ),
                    ),
              )
              .take(3)
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HeroImage(
          imageAsset: widget.group.imageAsset,
          visual: LicensedDiscoverVisual(
            title: widget.group.name,
            subtitle: widget.group.fandom,
            imageAsset: widget.group.imageAsset,
            imageUrl: widget.group.imageUrl,
            imageSource: widget.group.imageSource,
            imageLicense: widget.group.imageLicense,
            attribution: widget.group.attribution,
            author: widget.group.author,
            licenseUrl: widget.group.licenseUrl,
            showAttribution: true,
          ),
          eyebrow: '${widget.group.fandom} · ${widget.group.debut}',
          title: widget.group.name,
          subtitle: widget.group.style,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('discover-follow-group'),
                onPressed: () => setState(() => _following = !_following),
                icon: Icon(_following ? Icons.check : Icons.add),
                label: Text(_following ? 'Siguiendo' : 'Seguir grupo'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: _openGroupFancams,
              icon: const Icon(Icons.videocam_outlined),
              tooltip: 'Ver fancams',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoGrid(
          items: [
            ('Empresa', widget.group.company),
            ('Debut', widget.group.debut),
            ('Fandom', widget.group.fandom),
            ('Estado', widget.group.activityStatus.label),
            ('Integrantes', '${widget.group.idols.length}'),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Biografía', trailing: widget.group.latest),
        const SizedBox(height: 8),
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group.fullBio, style: _bodyStyle),
              const SizedBox(height: 14),
              _InlineChips(
                labels: [
                  widget.group.status.label,
                  widget.group.type.label,
                  widget.group.region,
                  widget.group.concept,
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Canciones y eras', trailing: 'curado'),
        const SizedBox(height: 10),
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabelBlock(
                title: 'Canciones recomendadas',
                values: widget.group.recommendedSongs,
              ),
              const SizedBox(height: 12),
              _LabelBlock(
                title: 'Eras / comebacks destacados',
                values: widget.group.featuredEras,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Canales oficiales', trailing: 'referencias'),
        const SizedBox(height: 10),
        _KeyValuePanel(items: widget.group.officialLinks.entries.toList()),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Integrantes',
          trailing: '${widget.group.idols.length} perfiles',
        ),
        const SizedBox(height: 10),
        ...widget.group.idols.map(
          (idol) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _IdolListTile(idol: idol, onTap: () => _openIdol(idol)),
          ),
        ),
        const SizedBox(height: 12),
        _SectionTitle(
          title: 'Fancams del fandom',
          trailing: '${groupFancams.length} etiquetadas',
        ),
        const SizedBox(height: 10),
        if (groupFancams.isEmpty)
          const _EmptyPanel(
            text:
                'Todavía no hay fancams etiquetadas para este grupo. La relación ya está preparada para nuevas publicaciones.',
          )
        else
          ...groupFancams.map(
            (fancam) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FancamPreview(fancam: fancam, onTap: _openGroupFancams),
            ),
          ),
        if (groupNews.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'Noticias relacionadas',
            trailing: '${groupNews.length} recientes',
          ),
          const SizedBox(height: 10),
          ...groupNews.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DarkPanel(
                child: Text(item.title, style: _compactTitleStyle),
              ),
            ),
          ),
        ],
        if (groupPosts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'Posts relacionados',
            trailing: '${groupPosts.length} publicaciones',
          ),
          const SizedBox(height: 10),
          ...groupPosts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PostPreview(post: post),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SectionTitle(title: 'Fuentes e imagen', trailing: 'uso legal'),
        const SizedBox(height: 10),
        _ImageRightsPanel(
          imageLicense: widget.group.imageLicense,
          imageSource: widget.group.imageSource,
          attribution: widget.group.attribution,
          author: widget.group.author,
          licenseUrl: widget.group.licenseUrl,
          officialUrl: widget.group.officialUrl,
          sources: widget.group.sources,
        ),
      ],
    );
  }
}

class IdolDetailScreen extends StatefulWidget {
  const IdolDetailScreen({
    super.key,
    required this.group,
    required this.idol,
    this.user,
    this.fancamService = const LocalFancamService(),
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.chatService = const LocalChatService(),
  });

  final DiscoverGroup group;
  final DiscoverIdol idol;
  final AuthUser? user;
  final LocalFancamService fancamService;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalChatService chatService;

  @override
  State<IdolDetailScreen> createState() => _IdolDetailScreenState();
}

class _IdolDetailScreenState extends State<IdolDetailScreen> {
  List<Fancam> _localFancams = [];
  bool _following = false;

  @override
  void initState() {
    super.initState();
    LocalFancamService.revision.addListener(_restoreLocalFancams);
    _restoreLocalFancams();
  }

  @override
  void dispose() {
    LocalFancamService.revision.removeListener(_restoreLocalFancams);
    super.dispose();
  }

  Future<void> _restoreLocalFancams() async {
    final local = await widget.fancamService.restoreFancams();
    if (!mounted) return;
    setState(() => _localFancams = local);
  }

  void _openFancams() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DiscoverPage(
          title: '${widget.idol.name} · Fancams',
          child: FancamsScreen(
            artistId: widget.idol.id,
            title: '${widget.idol.name} · Fancams',
            user: widget.user,
            fancamService: widget.fancamService,
            followService: widget.followService,
            postService: widget.postService,
            storyService: widget.storyService,
            dropService: widget.dropService,
            chatService: widget.chatService,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceFancams = widget.fancamService.usesRealFancams
        ? _localFancams
        : [..._localFancams, ...fancams];
    final related = sourceFancams
        .where((fancam) => fancam.artistId == widget.idol.id)
        .toList();
    final relatedPosts = widget.postService.usesRealPosts
        ? const <HubPost>[]
        : posts
              .where(
                (post) =>
                    [post.author, post.caption, post.location, ...post.tags]
                        .join(' ')
                        .toLowerCase()
                        .contains(widget.idol.name.toLowerCase()) ||
                    post.tags.any(
                      (tag) =>
                          tag.toLowerCase().contains(
                            widget.group.name.toLowerCase(),
                          ) ||
                          tag.toLowerCase().contains(
                            widget.group.fandom.toLowerCase(),
                          ),
                    ),
              )
              .take(3)
              .toList();
    final facts = [
      if (widget.idol.realName.isNotEmpty)
        ('Nombre real', widget.idol.realName),
      ('Grupo', widget.group.name),
      ('Rol', widget.idol.role),
      ('País', widget.idol.country),
      if (widget.idol.birth.isNotEmpty) ('Nacimiento', widget.idol.birth),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HeroImage(
          imageAsset: widget.idol.imageAsset,
          visual: LicensedDiscoverVisual(
            title: widget.idol.name,
            subtitle: widget.group.name,
            imageAsset: widget.idol.imageAsset,
            imageUrl: widget.idol.imageUrl,
            imageSource: widget.idol.imageSource,
            imageLicense: widget.idol.imageLicense,
            attribution: widget.idol.attribution,
            author: widget.idol.author,
            licenseUrl: widget.idol.licenseUrl,
            showAttribution: true,
          ),
          eyebrow: widget.group.name,
          title: widget.idol.name,
          subtitle: widget.idol.role,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('discover-follow-idol'),
                onPressed: () => setState(() => _following = !_following),
                icon: Icon(_following ? Icons.check : Icons.add),
                label: Text(_following ? 'Siguiendo' : 'Seguir artista'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              key: const ValueKey('discover-idol-fancams'),
              onPressed: _openFancams,
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Fancams etiquetadas',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.idol.fullBio.isEmpty
                    ? widget.idol.bio
                    : widget.idol.fullBio,
                style: _bodyStyle,
              ),
              const SizedBox(height: 14),
              _InlineChips(labels: widget.idol.highlights),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InfoGrid(items: facts),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Fancams de fans',
          trailing: '${related.length} etiquetadas',
        ),
        const SizedBox(height: 10),
        if (related.isEmpty)
          const _EmptyPanel(
            text:
                'Todavía no hay fancams para este idol. Las nuevas publicaciones etiquetadas aparecerán acá.',
          )
        else
          ...related.map(
            (fancam) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FancamPreview(fancam: fancam, onTap: _openFancams),
            ),
          ),
        if (relatedPosts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'Posts relacionados',
            trailing: '${relatedPosts.length} publicaciones',
          ),
          const SizedBox(height: 10),
          ...relatedPosts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PostPreview(post: post),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SectionTitle(title: 'Imagen y fuentes', trailing: 'uso legal'),
        const SizedBox(height: 10),
        _ImageRightsPanel(
          imageLicense: widget.idol.imageLicense,
          imageSource: widget.idol.imageSource,
          attribution: widget.idol.attribution,
          author: widget.idol.author,
          licenseUrl: widget.idol.licenseUrl,
          officialUrl: widget.idol.officialUrl,
          sources: const [
            'Resumen redactado por HallyuHub',
            'Validar con fuente oficial antes de producción',
          ],
        ),
      ],
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.item, this.onShareToPost});

  final DiscoverNews item;
  final VoidCallback? onShareToPost;

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir este enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final directUrl = item.directArticleUrl;
    final relatedUrl = item.relatedResultsUrl;
    final badgeColor = switch (item.editorialBadge) {
      'Oficial' || 'Confirmado' => AppTheme.cyan,
      'Rumor' => AppTheme.amber,
      'En desarrollo' => AppTheme.violet,
      _ => AppTheme.rose,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _NewsDetailHeader(item: item, badgeColor: badgeColor),
        const SizedBox(height: 14),
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('En pocas palabras', style: _compactTitleStyle),
              const SizedBox(height: 8),
              Text(item.displaySummary, style: _bodyStyle),
              if (item.displayTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InlineChips(labels: item.displayTags),
              ],
            ],
          ),
        ),
        if (item.whyItMatters.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _DarkPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Por qué importa', style: _compactTitleStyle),
                const SizedBox(height: 8),
                Text(item.whyItMatters, style: _bodyStyle),
              ],
            ),
          ),
        ],
        if (onShareToPost != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const ValueKey('discover-news-share-to-post'),
            onPressed: onShareToPost,
            icon: const Icon(Icons.post_add_rounded),
            label: const Text('Compartir en una publicación'),
          ),
        ],
        if (directUrl.isNotEmpty || relatedUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('discover-news-open-original'),
            onPressed: () => _openExternal(
              context,
              directUrl.isNotEmpty ? directUrl : relatedUrl,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(
              directUrl.isNotEmpty
                  ? 'Leer en ${item.displaySource}'
                  : 'Ver resultados relacionados',
            ),
          ),
        ],
      ],
    );
  }
}

class _NewsDetailHeader extends StatelessWidget {
  const _NewsDetailHeader({required this.item, required this.badgeColor});

  final DiscoverNews item;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: badgeColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: SizedBox(
              height: 188,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NewsDetailVisual(item: item, accent: badgeColor),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.night.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: _MiniPill(item.editorialBadge),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.entityLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${item.displaySource} · ${item.publishedLabel}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsDetailVisual extends StatelessWidget {
  const _NewsDetailVisual({required this.item, required this.accent});

  final DiscoverNews item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (item.hasAuthorizedImage) {
      return Image.network(
        item.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (item.imageAsset.trim().isNotEmpty) {
      return Image.asset(
        item.imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.35),
            AppTheme.violet.withValues(alpha: 0.2),
            AppTheme.night,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          size: 54,
          color: Colors.white.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}

class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({super.key, required this.community});

  final DiscoverCommunity community;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _controller = TextEditingController();
  late final List<_CommunityChatMessage> _messages = _initialMessages();
  bool _joined = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _messages.add(
        _CommunityChatMessage(
          id: 'community-message-${DateTime.now().microsecondsSinceEpoch}',
          profile: null,
          body: value,
          time: 'Ahora',
          mine: true,
        ),
      );
      _controller.clear();
    });
  }

  List<_CommunityChatMessage> _initialMessages() {
    final profiles = demoProfiles.take(5).toList(growable: false);
    return [
      for (var index = 0; index < widget.community.posts.length; index++)
        _CommunityChatMessage(
          id: '${widget.community.id}-seed-$index',
          profile: profiles[index % profiles.length],
          body: widget.community.posts[index],
          time: index == 0 ? 'Hace 12 min' : 'Hace ${index + 2} min',
        ),
    ];
  }

  void _openMemberProfile(CommunityProfile? profile) {
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StoryProfileScreen(
          story: Story(
            id: 'community-profile-${profile.id}',
            authorId: profile.id,
            name: profile.name,
            fandom: profile.fandom,
            avatarAsset: profile.avatarAsset,
            imageAsset: profile.coverAsset,
            title: profile.username,
            detail: profile.bio,
            timeLabel: 'Comunidad',
            isLive: profile.online,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = discoverEvents
        .where((event) => event.communityId == widget.community.id)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.community.fandom, style: _eyebrowStyle),
              const SizedBox(height: 6),
              Text(widget.community.name, style: _detailTitleStyle),
              const SizedBox(height: 6),
              Text(widget.community.region, style: _mutedStyle),
              const SizedBox(height: 12),
              Text(widget.community.description, style: _bodyStyle),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniPill(widget.community.members),
                  _MiniPill(widget.community.activity),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('discover-community-join'),
                onPressed: () => setState(() => _joined = !_joined),
                icon: Icon(_joined ? Icons.check : Icons.group_add_outlined),
                label: Text(_joined ? 'Te uniste' : 'Unirme'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Chat de comunidad',
          trailing: '${_messages.length}',
        ),
        const SizedBox(height: 10),
        const HallyFeatureTip(
          featureId: 'community_chat_intro',
          title: 'Este chat es de todos 💬',
          message: 'Tocá un nombre o avatar para visitar ese perfil.',
          mascotAsset: 'assets/brand/hally_mascot_community.png',
        ),
        _CommunityChatPanel(
          community: widget.community,
          messages: _messages,
          controller: _controller,
          joined: _joined,
          onSend: _send,
          onProfile: _openMemberProfile,
        ),
        if (!_joined) ...[
          const SizedBox(height: 8),
          Text(
            'Podés leer el chat; para participar, tocá Unirme.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (events.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Eventos relacionados',
            trailing: '${events.length}',
          ),
          const SizedBox(height: 10),
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DarkPanel(
                child: Text(
                  '${event.title} · ${event.date}',
                  style: _bodyStyle,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommunityChatMessage {
  const _CommunityChatMessage({
    required this.id,
    required this.profile,
    required this.body,
    required this.time,
    this.mine = false,
  });

  final String id;
  final CommunityProfile? profile;
  final String body;
  final String time;
  final bool mine;
}

class _CommunityChatPanel extends StatelessWidget {
  const _CommunityChatPanel({
    required this.community,
    required this.messages,
    required this.controller,
    required this.joined,
    required this.onSend,
    required this.onProfile,
  });

  final DiscoverCommunity community;
  final List<_CommunityChatMessage> messages;
  final TextEditingController controller;
  final bool joined;
  final VoidCallback onSend;
  final ValueChanged<CommunityProfile?> onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.rose.withValues(alpha: 0.9),
                        AppTheme.cyan.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.forum_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${community.members} · ${community.activity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                for (final message in messages)
                  _CommunityChatBubble(
                    message: message,
                    onProfile: () => onProfile(message.profile),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('discover-community-message'),
                    controller: controller,
                    enabled: joined,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: joined
                          ? 'Escribí en la comunidad...'
                          : 'Unite para escribir...',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => joined ? onSend() : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('discover-community-send'),
                  onPressed: joined ? onSend : null,
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Enviar',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityChatBubble extends StatelessWidget {
  const _CommunityChatBubble({required this.message, required this.onProfile});

  final _CommunityChatMessage message;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final profile = message.profile;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            GestureDetector(
              onTap: onProfile,
              child: HubAvatar(
                asset: profile?.avatarAsset ?? 'assets/demo-users/user-01.jpg',
                size: 34,
                isLive: profile?.online ?? false,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!mine && profile != null)
                  GestureDetector(
                    onTap: onProfile,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: mine
                        ? LinearGradient(
                            colors: [
                              AppTheme.rose.withValues(alpha: 0.94),
                              AppTheme.violet.withValues(alpha: 0.86),
                            ],
                          )
                        : null,
                    color: mine ? null : Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 18),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: mine ? 0.18 : 0.08),
                    ),
                  ),
                  child: Text(
                    message.body,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final DiscoverEvent event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _attending = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HeroImage(
          imageAsset: widget.event.imageAsset,
          eyebrow: widget.event.fandom,
          title: widget.event.title,
          subtitle: '${widget.event.date} · ${widget.event.city}',
        ),
        const SizedBox(height: 16),
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.event.location, style: _compactTitleStyle),
              const SizedBox(height: 6),
              Text(
                '${widget.event.city}, ${widget.event.country}',
                style: _mutedStyle,
              ),
              const SizedBox(height: 14),
              Text(widget.event.description, style: _bodyStyle),
              const SizedBox(height: 12),
              Text('Organiza ${widget.event.organizer}', style: _eyebrowStyle),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('discover-event-attend'),
                onPressed: () => setState(() => _attending = !_attending),
                icon: Icon(_attending ? Icons.check : Icons.event_available),
                label: Text(_attending ? 'Voy a asistir' : 'Asistir'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => setState(() => _saved = !_saved),
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
              tooltip: _saved ? 'Guardado' : 'Guardar',
            ),
          ],
        ),
      ],
    );
  }
}

class GuideDetailScreen extends StatefulWidget {
  const GuideDetailScreen({super.key, required this.guide});

  final DiscoverGuide guide;

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  bool _saved = false;

  void _share() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Opciones para compartir guía abiertas'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.guide.category, style: _eyebrowStyle),
              const SizedBox(height: 8),
              Text(widget.guide.title, style: _detailTitleStyle),
              const SizedBox(height: 10),
              Text(widget.guide.summary, style: _mutedStyle),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DarkPanel(child: Text(widget.guide.body, style: _bodyStyle)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('discover-guide-save'),
                onPressed: () => setState(() => _saved = !_saved),
                icon: Icon(
                  _saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                ),
                label: Text(_saved ? 'Guía guardada' : 'Guardar guía'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: 'Compartir guía',
            ),
          ],
        ),
      ],
    );
  }
}

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.store});

  final DiscoverStore store;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final _wishlist = <String>{};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HeroImage(
          imageAsset: widget.store.imageAsset,
          eyebrow: widget.store.verified
              ? 'Tienda verificada · Demo local'
              : 'Demo local',
          title: widget.store.name,
          subtitle: '${widget.store.city}, ${widget.store.country}',
        ),
        const SizedBox(height: 14),
        _DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.store.category, style: _eyebrowStyle),
              const SizedBox(height: 6),
              Text(widget.store.description, style: _bodyStyle),
              const SizedBox(height: 10),
              Text(
                '★ ${widget.store.rating} confianza',
                style: _compactTitleStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Productos destacados',
          trailing: 'Sin pagos todavía',
        ),
        const SizedBox(height: 10),
        ...widget.store.products.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DarkPanel(
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppTheme.cyan),
                  const SizedBox(width: 10),
                  Expanded(child: Text(product, style: _compactTitleStyle)),
                  IconButton(
                    onPressed: () => setState(() {
                      if (!_wishlist.add(product)) _wishlist.remove(product);
                    }),
                    icon: Icon(
                      _wishlist.contains(product)
                          ? Icons.bookmark
                          : Icons.bookmark_add_outlined,
                      color: AppTheme.rose,
                    ),
                    tooltip: 'Guardar en wishlist',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ScalableEntityDetailScreen extends StatefulWidget {
  const ScalableEntityDetailScreen({super.key, required this.entity});

  final DiscoverArtistEntity entity;

  @override
  State<ScalableEntityDetailScreen> createState() =>
      _ScalableEntityDetailScreenState();
}

class _ScalableEntityDetailScreenState
    extends State<ScalableEntityDetailScreen> {
  bool _following = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final relatedNews = discoverNews
        .where(
          (item) =>
              item.relatedEntityIds.contains(widget.entity.groupId) ||
              item.detectedEntityTags.contains(widget.entity.name),
        )
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HeroImage(
          imageAsset: widget.entity.imageAsset,
          visual: LicensedDiscoverVisual(
            title: widget.entity.name,
            subtitle: widget.entity.fandom,
            imageAsset: widget.entity.imageAsset,
            imageUrl: widget.entity.imageUrl,
            imageSource: widget.entity.imageSource,
            imageLicense: widget.entity.imageLicense,
            attribution: widget.entity.attribution,
            author: widget.entity.author,
            licenseUrl: widget.entity.licenseUrl,
            showAttribution: true,
          ),
          eyebrow: widget.entity.status.label,
          title: widget.entity.name,
          subtitle: '${widget.entity.type.label} · ${widget.entity.region}',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() => _following = !_following),
                icon: Icon(_following ? Icons.check : Icons.add),
                label: Text(_following ? 'Siguiendo' : 'Seguir entidad'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => setState(() => _saved = !_saved),
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_add_outlined),
              tooltip: 'Guardar',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DarkPanel(child: Text(widget.entity.description, style: _bodyStyle)),
        const SizedBox(height: 18),
        _InfoGrid(
          items: [
            ('Tipo', widget.entity.type.label),
            ('Estado', widget.entity.status.label),
            ('País', widget.entity.country),
            ('Origen', _cleanDemoLabel(widget.entity.source)),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Datos preparados', trailing: 'Supabase-ready'),
        const SizedBox(height: 10),
        _DarkPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill('groupId: ${widget.entity.groupId}'),
              _MiniPill('Origen: ${_cleanDemoLabel(widget.entity.createdBy)}'),
              _MiniPill('updated: ${widget.entity.lastUpdated}'),
              if (widget.entity.referenceUrl.isNotEmpty)
                _MiniPill('referencia adjunta'),
            ],
          ),
        ),
        if (widget.entity.tags.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Tags',
            trailing: '${widget.entity.tags.length}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in widget.entity.tags.take(10)) _MiniPill(tag),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Noticias detectadas',
          trailing: '${relatedNews.length}',
        ),
        const SizedBox(height: 10),
        if (relatedNews.isEmpty)
          const _EmptyPanel(
            text:
                'Todavía no hay noticias vinculadas. La entidad puede existir como sugerencia sin ficha completa.',
          )
        else
          ...relatedNews.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DarkPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.status, style: _eyebrowStyle),
                    const SizedBox(height: 5),
                    Text(item.title, style: _compactTitleStyle),
                    const SizedBox(height: 5),
                    Text(item.summary, style: _mutedStyle),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Imagen', trailing: 'uso legal'),
        const SizedBox(height: 10),
        _ImageRightsPanel(
          imageLicense: widget.entity.imageLicense,
          imageSource: widget.entity.imageSource,
          attribution: widget.entity.attribution,
          author: widget.entity.author,
          licenseUrl: widget.entity.licenseUrl,
          officialUrl: widget.entity.officialUrl,
          sources: const [
            'Entidad sugerida por comunidad',
            'Reemplazar visual solo con licencia clara',
          ],
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageAsset,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.visual,
  });

  final String imageAsset;
  final Widget? visual;
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _NeonFrame(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: AspectRatio(
          aspectRatio: 1.05,
          child: Stack(
            fit: StackFit.expand,
            children: [
              visual ?? Image.asset(imageAsset, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.02),
                      AppTheme.night.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: _GradientPill(label: eyebrow),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _heroTitleStyle, maxLines: 2),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: _mutedStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in items)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width.clamp(0, 520) - 42) / 2,
            child: _DarkPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _mutedStyle),
                  const SizedBox(height: 5),
                  Text(value, style: _compactTitleStyle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InlineChips extends StatelessWidget {
  const _InlineChips({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final visible = labels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.rose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.16)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _LabelBlock extends StatelessWidget {
  const _LabelBlock({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _compactTitleStyle),
        const SizedBox(height: 8),
        _InlineChips(labels: values),
      ],
    );
  }
}

class _KeyValuePanel extends StatelessWidget {
  const _KeyValuePanel({required this.items});

  final List<MapEntry<String, String>> items;

  @override
  Widget build(BuildContext context) {
    return _DarkPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in items) ...[
            Text(entry.key, style: _eyebrowStyle),
            const SizedBox(height: 3),
            Text(entry.value, style: _bodyStyle),
            if (entry != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.post});

  final HubPost post;

  @override
  Widget build(BuildContext context) {
    return _DarkPanel(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              post.imageAsset,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contenido del fandom', style: _compactTitleStyle),
                const SizedBox(height: 4),
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle,
                ),
                const SizedBox(height: 6),
                Text('Vista previa editorial', style: _eyebrowStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageRightsPanel extends StatelessWidget {
  const _ImageRightsPanel({
    required this.imageLicense,
    required this.imageSource,
    required this.attribution,
    required this.author,
    required this.licenseUrl,
    required this.officialUrl,
    required this.sources,
  });

  final String imageLicense;
  final String imageSource;
  final String attribution;
  final String author;
  final String licenseUrl;
  final String officialUrl;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Licencia visual', imageLicense),
      (
        'Fuente visual',
        imageSource.isEmpty ? 'Placeholder local' : imageSource,
      ),
      ('Atribución', attribution),
      ('Autor', author),
      if (licenseUrl.isNotEmpty) ('URL licencia', licenseUrl),
      if (officialUrl.isNotEmpty) ('URL oficial', officialUrl),
      ...sources.map((source) => ('Referencia', source)),
    ];
    return _DarkPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Política interna de imagen', style: _compactTitleStyle),
          const SizedBox(height: 8),
          Text(
            'No se usan fotos reales sin permiso. Estos placeholders se reemplazan solo por imágenes autorizadas, Creative Commons con atribución correcta, press kits con permiso o contenido subido por usuarios.',
            style: _mutedStyle,
          ),
          const SizedBox(height: 12),
          for (final (label, value) in rows) ...[
            Text(label, style: _eyebrowStyle),
            const SizedBox(height: 2),
            Text(value, style: _bodyStyle),
            if ((label, value) != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _IdolListTile extends StatelessWidget {
  const _IdolListTile({required this.idol, required this.onTap});

  final DiscoverIdol idol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        key: ValueKey('discover-idol-${idol.id}'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 62,
                height: 68,
                child: LicensedDiscoverVisual(
                  title: idol.name,
                  subtitle: idol.role,
                  imageAsset: idol.imageAsset,
                  imageUrl: idol.imageUrl,
                  imageSource: idol.imageSource,
                  imageLicense: idol.imageLicense,
                  attribution: idol.attribution,
                  author: idol.author,
                  licenseUrl: idol.licenseUrl,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(idol.name, style: _compactTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    idol.role,
                    style: _mutedStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.cyan),
          ],
        ),
      ),
    );
  }
}

class _FancamPreview extends StatelessWidget {
  const _FancamPreview({required this.fancam, required this.onTap});

  final Fancam fancam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.rose.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    fancam.imageAsset,
                    width: 70,
                    height: 82,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.night.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fancam.artist, style: _eyebrowStyle),
                  const SizedBox(height: 4),
                  Text(fancam.title, style: _compactTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    '${fancam.creator} · ${fancam.duration}',
                    style: _mutedStyle,
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.rose.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: AppTheme.rose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}

class _NeonFrame extends StatelessWidget {
  const _NeonFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppTheme.cyan.withValues(alpha: 0.42),
            AppTheme.rose.withValues(alpha: 0.34),
            AppTheme.violet.withValues(alpha: 0.46),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(margin: const EdgeInsets.all(1), child: child),
    );
  }
}

class _GradientPill extends StatelessWidget {
  const _GradientPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.rose.withValues(alpha: 0.9),
            AppTheme.violet.withValues(alpha: 0.75),
            AppTheme.cyan.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: _pillStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: _sectionTitleStyle)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            style: _eyebrowStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DarkPanel extends StatelessWidget {
  const _DarkPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _DarkPanel(child: Text(text, style: _mutedStyle));
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.violet.withValues(alpha: 0.24),
            AppTheme.cyan.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.18)),
      ),
      child: Text(label, style: _eyebrowStyle),
    );
  }
}

const _heroTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 27,
  fontWeight: FontWeight.w900,
);
const _detailTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 23,
  fontWeight: FontWeight.w900,
);
const _sectionTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 19,
  fontWeight: FontWeight.w900,
);
const _compactTitleStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w900,
);
const _pillStyle = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.w900,
);
const _bodyStyle = TextStyle(
  color: Colors.white,
  height: 1.45,
  fontWeight: FontWeight.w600,
);
final _mutedStyle = TextStyle(
  color: Colors.white.withValues(alpha: 0.68),
  height: 1.35,
  fontWeight: FontWeight.w600,
);
const _eyebrowStyle = TextStyle(
  color: AppTheme.cyan,
  fontSize: 12,
  fontWeight: FontWeight.w900,
);
