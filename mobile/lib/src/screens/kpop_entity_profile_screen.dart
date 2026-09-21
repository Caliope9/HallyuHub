import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/discover_data.dart';
import '../models.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/kpop_entity_follow_service.dart';
import '../services/kpop_entity_member_service.dart';
import '../services/news_service.dart';
import '../services/local_safety_service.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/kpop_entity_reference.dart';
import '../utils/kpop_follower_count_formatter.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/shared_news_post_card.dart';
import 'drops_screen.dart';
import 'fancams_screen.dart';

enum _EntityTab { home, info, members, events, media }

enum _EntityFeedFilter { all, fans, videos, images }

class KpopEntityProfileScreen extends StatefulWidget {
  const KpopEntityProfileScreen({
    super.key,
    required this.entity,
    required this.currentUser,
    required this.artistTagService,
    required this.postService,
    required this.storyService,
    required this.dropService,
    required this.fancamService,
    required this.followService,
    required this.chatService,
    required this.contentCategoryService,
    required this.userTagService,
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
  });

  final KpopEntity entity;
  final AuthUser? currentUser;
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

  @override
  State<KpopEntityProfileScreen> createState() =>
      _KpopEntityProfileScreenState();
}

class _KpopEntityProfileScreenState extends State<KpopEntityProfileScreen> {
  _EntityTab _tab = _EntityTab.home;
  _EntityFeedFilter _filter = _EntityFeedFilter.all;
  List<HubPost> _posts = const [];
  List<Story> _stories = const [];
  List<DropClip> _drops = const [];
  List<Fancam> _fancams = const [];
  _EntityEditorialData _editorial = const _EntityEditorialData();
  List<DiscoverNews> _news = const [];
  bool _showAllNews = false;
  bool _followingEntity = false;
  bool _followBusy = false;
  bool _followerCountLoading = true;
  int? _followerCount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalArtistTagService.revision.addListener(_restore);
    _restore();
  }

  @override
  void dispose() {
    LocalArtistTagService.revision.removeListener(_restore);
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      final postIds = await widget.artistTagService.restoreContentIdsForEntity(
        contentType: ProfileContentType.post,
        entityId: widget.entity.id,
      );
      final posts =
          postIds.isEmpty && !widget.artistTagService.usesRealArtistTags
          ? await widget.postService.restorePosts(limit: 24)
          : await widget.postService.restorePostsByIds(
              postIds,
              limit: postIds.length.clamp(24, 100),
            );
      final drops = await widget.dropService.restoreDrops(limit: 24);
      final fancams = await widget.fancamService.restoreFancams(limit: 24);
      final followingIds = await widget.followService.restoreFollowingIds();
      final ownStories = await widget.storyService.restoreOwnStories();
      final followingStories = await widget.storyService
          .restoreFollowingStories(followingIds: followingIds);
      final postTags = await widget.artistTagService.restoreForContents(
        contentType: ProfileContentType.post,
        contentIds: posts.map((item) => item.id),
      );
      final storyTags = await widget.artistTagService.restoreForContents(
        contentType: ProfileContentType.story,
        contentIds: [...ownStories, ...followingStories].map((item) => item.id),
      );
      final dropTags = await widget.artistTagService.restoreForContents(
        contentType: ProfileContentType.drop,
        contentIds: drops.map((item) => item.id),
      );
      final fancamTags = await widget.artistTagService.restoreForContents(
        contentType: ProfileContentType.fancam,
        contentIds: fancams.map((item) => item.id),
      );
      final news = await _restoreRelatedNews();
      final editorial = await _restoreEditorialData();
      final followingEntity = await _restoreFollowingEntity();
      final followerCount = await _restoreFollowerCount();
      if (!mounted) return;
      setState(() {
        _posts = posts
            .where((item) => _hasEntity(postTags[item.id]))
            .toList(growable: false);
        _stories = [...ownStories, ...followingStories]
            .where((item) => _hasEntity(storyTags[item.id]))
            .toList(growable: false);
        _drops = drops
            .where(
              (item) =>
                  _hasEntity(dropTags[item.id]) ||
                  (!widget.artistTagService.usesRealArtistTags &&
                      _dropHasEntity(item)),
            )
            .toList(growable: false);
        _fancams = fancams
            .where(
              (item) =>
                  _hasEntity(fancamTags[item.id]) ||
                  (!widget.artistTagService.usesRealArtistTags &&
                      _fancamHasEntity(item)),
            )
            .toList(growable: false);
        _editorial = editorial;
        _news = news;
        _followingEntity = followingEntity;
        _followerCount = followerCount;
        _followerCountLoading = false;
        _loading = false;
      });
    } catch (error) {
      debugPrint('KPOP_ENTITY_RESTORE_ERROR ${widget.entity.id} $error');
      if (!mounted) return;
      setState(() {
        _posts = const [];
        _stories = const [];
        _drops = const [];
        _fancams = const [];
        _news = const [];
        _followerCountLoading = false;
        _loading = false;
      });
    }
  }

  bool _hasEntity(List<ContentArtistTag>? tags) {
    if (tags == null || tags.isEmpty) return false;
    if (tags.any((tag) => tag.entityId == widget.entity.id)) return true;
    if (widget.artistTagService.usesRealArtistTags) return false;
    return tags.any(
      (tag) =>
          tag.entity != null &&
          kpopEntitiesShareIdentity(widget.entity, tag.entity!),
    );
  }

  Future<List<DiscoverNews>> _restoreRelatedNews() async {
    final isReal = widget.artistTagService.usesRealArtistTags;
    try {
      final candidates = isReal
          ? await SupabaseNewsService().restoreNews(limit: 100)
          : discoverNews;
      final entityKeys = _entityLookupKeys(widget.entity);
      return candidates
          .where((item) {
            if (item.relatedEntityIds.contains(widget.entity.id)) return true;
            if (isReal) return false;
            final explicitReferences = [
              item.artist,
              ...item.relatedGroups,
              ...item.relatedArtists,
            ].map(_compactEntityKey).where((key) => key.isNotEmpty);
            return explicitReferences.any(entityKeys.contains);
          })
          .toList(growable: false);
    } catch (error) {
      debugPrint('KPOP_ENTITY_NEWS_ERROR ${widget.entity.id} $error');
      return const [];
    }
  }

  bool _dropHasEntity(DropClip drop) {
    return _matchesEntityReferences(
      ids: <String>[drop.artistId],
      names: <String>[drop.artist],
      taggedEntities: drop.taggedEntities,
    );
  }

  bool _fancamHasEntity(Fancam fancam) {
    return _matchesEntityReferences(
      ids: <String>[fancam.artistId],
      names: <String>[fancam.artist],
      taggedEntities: fancam.taggedEntities,
    );
  }

  bool _matchesEntityReferences({
    Iterable<String> ids = const <String>[],
    Iterable<String> names = const <String>[],
    Iterable<KpopEntity> taggedEntities = const <KpopEntity>[],
  }) {
    if (ids.any((id) => id.trim() == widget.entity.id)) return true;
    final currentKeys = _entityLookupKeys(widget.entity);
    final referenceKeys = <String>{
      ...ids.map(_compactEntityKey),
      ...names.map(_compactEntityKey),
    }..remove('');
    if (referenceKeys.any(currentKeys.contains)) return true;
    return taggedEntities.any((entity) {
      return kpopEntitiesShareIdentity(widget.entity, entity);
    });
  }

  Future<_EntityEditorialData> _restoreEditorialData() async {
    final fallback = _EntityEditorialData.forEntity(widget.entity);
    if (!_looksLikeUuid(widget.entity.id)) return fallback;
    try {
      final rows = await supabase.Supabase.instance.client
          .from('kpop_entities')
          .select('bio,fandom_name,agency,country,debut_year')
          .eq('id', widget.entity.id)
          .limit(1);
      final castRows = rows.cast<Map<String, dynamic>>();
      if (castRows.isEmpty) return fallback;
      final editorial = _EntityEditorialData.fromRow(
        castRows.first,
        fallback: fallback,
      );
      if (widget.entity.type != KpopEntityType.group) return editorial;
      final remoteMembers = await KpopEntityMemberService().restoreMembers(
        widget.entity.id,
      );
      if (remoteMembers == null) return editorial;
      return editorial.withMemberProfiles(remoteMembers);
    } catch (error) {
      debugPrint('KPOP_ENTITY_EDITORIAL_ERROR ${widget.entity.id} $error');
      return fallback;
    }
  }

  Future<bool> _restoreFollowingEntity() async {
    if (!_looksLikeUuid(widget.entity.id)) return false;
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return false;
    try {
      final rows = await client
          .from('kpop_entity_follows')
          .select('entity_id')
          .eq('entity_id', widget.entity.id)
          .eq('user_id', authUser.id)
          .limit(1);
      return rows.isNotEmpty;
    } catch (error) {
      debugPrint('KPOP_ENTITY_FOLLOW_RESTORE_ERROR ${widget.entity.id} $error');
      return false;
    }
  }

  Future<int?> _restoreFollowerCount() async {
    if (!_looksLikeUuid(widget.entity.id)) return null;
    final client = supabase.Supabase.instance.client;
    if (client.auth.currentUser == null) return null;
    try {
      return await KpopEntityFollowService(
        client,
      ).restoreFollowerCount(widget.entity.id);
    } catch (error) {
      debugPrint('KPOP_ENTITY_FOLLOWER_COUNT_ERROR ${widget.entity.id} $error');
      return null;
    }
  }

  Future<void> _toggleEntityFollow() async {
    if (_followBusy) return;
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null || !_looksLikeUuid(widget.entity.id)) {
      _showSnack('Iniciá sesión para seguir artistas.');
      return;
    }
    final wasFollowing = _followingEntity;
    final previousCount = _followerCount;
    final optimisticCount = previousCount == null
        ? null
        : wasFollowing
        ? (previousCount - 1).clamp(0, previousCount)
        : previousCount + 1;
    setState(() {
      _followBusy = true;
      _followingEntity = !wasFollowing;
      _followerCount = optimisticCount;
    });
    try {
      final followService = KpopEntityFollowService(client);
      await followService.setFollowing(
        entityId: widget.entity.id,
        userId: authUser.id,
        following: !wasFollowing,
      );
      LocalFollowService.revision.value++;
      int? refreshedCount;
      try {
        refreshedCount = await followService.restoreFollowerCount(
          widget.entity.id,
        );
      } catch (error) {
        debugPrint(
          'KPOP_ENTITY_FOLLOWER_REFRESH_ERROR ${widget.entity.id} $error',
        );
      }
      if (!mounted) return;
      setState(() {
        _followerCount = refreshedCount ?? optimisticCount;
        _followBusy = false;
      });
    } catch (error) {
      debugPrint('KPOP_ENTITY_FOLLOW_TOGGLE_ERROR ${widget.entity.id} $error');
      if (!mounted) return;
      setState(() {
        _followingEntity = wasFollowing;
        _followerCount = previousCount;
        _followBusy = false;
      });
      _showSnack('No pudimos guardar el seguimiento. Probá de nuevo.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openMember(String name) async {
    final entity = await resolveKpopEntityReference(
      artistTagService: widget.artistTagService,
      name: name,
    );
    if (entity == null) {
      _showSnack('Pronto vamos a completar la ficha de $name.');
      return;
    }
    if (!mounted) return;
    _openMemberEntity(entity);
  }

  void _openMemberEntity(KpopEntity selectedEntity) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => KpopEntityProfileScreen(
          entity: selectedEntity,
          currentUser: widget.currentUser,
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

  @override
  Widget build(BuildContext context) {
    final tabs = <_EntityTab>[
      _EntityTab.home,
      _EntityTab.info,
      if (widget.entity.type == KpopEntityType.group) _EntityTab.members,
      _EntityTab.events,
      _EntityTab.media,
    ];
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: const Color(0xFF050710),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          widget.entity.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                children: [
                  _EntityHeader(
                    entity: widget.entity,
                    editorial: _editorial,
                    following: _followingEntity,
                    followBusy: _followBusy,
                    followerCount: _followerCount,
                    followerCountLoading: _followerCountLoading,
                    onFollow: _toggleEntityFollow,
                  ),
                  if (widget.entity.imageSource.trim().isNotEmpty ||
                      widget.entity.imageLicense.trim().isNotEmpty ||
                      widget.entity.attribution.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _EntityImageCredit(entity: widget.entity),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
                    child: _EntityTabs(
                      selected: _tab,
                      tabs: tabs,
                      counts: {
                        _EntityTab.home: _posts.length + _news.length,
                        _EntityTab.members: _editorial.members.length,
                        _EntityTab.media:
                            _stories.length + _drops.length + _fancams.length,
                      },
                      onSelected: (tab) => setState(() => _tab = tab),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _loading ? const _EntityLoading() : _tabContent(),
                  ),
                ],
              ),
            ),
          ),
          const HallyFeatureTip(
            featureId: 'artist_profile_intro',
            title: 'Hally te cuenta 💜',
            message:
                'Acá vas a encontrar publicaciones y noticias etiquetadas. ¡Etiquetá a este artista o grupo para compartir tu post!',
          ),
        ],
      ),
    );
  }

  Widget _tabContent() {
    return switch (_tab) {
      _EntityTab.home => _homeContent(),
      _EntityTab.info => _infoContent(),
      _EntityTab.members => _membersContent(),
      _EntityTab.events => _eventsContent(),
      _EntityTab.media => _mediaContent(),
    };
  }

  Widget _homeContent() {
    // Editorial news has its own section and must never be mixed into the
    // social/community publication stream below.
    final socialPosts = _posts
        .where(
          (post) =>
              SharedNewsPostContent.fromCaption(post.caption).news == null,
        )
        .toList(growable: false);
    final filteredPosts = socialPosts
        .where(_matchesFilter)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntitySectionHeading(
          title: 'Noticias recientes',
          trailing: '${_news.length > 4 ? 4 : _news.length}',
        ),
        const SizedBox(height: 10),
        if (_news.isEmpty)
          _emptyPanel('Todavía no hay noticias recientes de este artista.')
        else ...[
          ..._news.take(_showAllNews ? _news.length : 4).map(_newsCard),
          if (_news.length > 4 && !_showAllNews)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _showAllNews = true),
                child: const Text('Ver todas'),
              ),
            ),
        ],
        const SizedBox(height: 14),
        _EntitySectionHeading(
          title: 'Últimas publicaciones',
          trailing: '${filteredPosts.length}',
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _EntityFeedFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('entity-feed-filter-${filter.name}'),
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (filteredPosts.isEmpty)
          _emptyPanel(
            'Todavía no hay publicaciones de fans para ${widget.entity.name}.',
          )
        else
          ...filteredPosts.map(_postCard),
      ],
    );
  }

  bool _matchesFilter(HubPost post) {
    final sharedNews = SharedNewsPostContent.fromCaption(post.caption).news;
    return switch (_filter) {
      _EntityFeedFilter.all => true,
      _EntityFeedFilter.fans => sharedNews == null,
      _EntityFeedFilter.videos => post.hasVideoMedia,
      _EntityFeedFilter.images => post.effectiveMediaItems.any(
        (item) => !item.isVideo,
      ),
    };
  }

  String _filterLabel(_EntityFeedFilter filter) => switch (filter) {
    _EntityFeedFilter.all => 'Todas',
    _EntityFeedFilter.fans => 'Solo fans',
    _EntityFeedFilter.videos => 'Videos',
    _EntityFeedFilter.images => 'Imágenes',
  };

  Widget _infoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntityBioSection(entity: widget.entity, editorial: _editorial),
        const SizedBox(height: 14),
        _EntityDiscographySection(items: _editorial.discography),
        const SizedBox(height: 14),
        _EntityInfoPanel(
          title: 'Datos',
          icon: Icons.info_outline_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_editorial.agency.isNotEmpty)
                _EntityInfoPill(label: _editorial.agency),
              if (_editorial.country.isNotEmpty)
                _EntityInfoPill(label: _editorial.country),
              if (_editorial.fandom.isNotEmpty)
                _EntityInfoPill(label: _editorial.fandom),
              if (_editorial.debutYear.isNotEmpty)
                _EntityInfoPill(label: 'Debut ${_editorial.debutYear}'),
              if (_editorial.groupName.isNotEmpty)
                _EntityInfoPill(label: 'Grupo: ${_editorial.groupName}'),
              if (_editorial.role.isNotEmpty)
                _EntityInfoPill(label: _editorial.role),
              _EntityInfoPill(label: widget.entity.type.label),
            ],
          ),
        ),
      ],
    );
  }

  Widget _membersContent() {
    if (widget.entity.type != KpopEntityType.group) {
      return _emptyPanel('Esta sección solo está disponible para grupos.');
    }
    return _EntityMembersSection(
      entity: widget.entity,
      members: _editorial.members,
      memberProfiles: _editorial.memberProfiles,
      onMember: _openMember,
      onMemberEntity: _openMemberEntity,
    );
  }

  Widget _eventsContent() => _emptyPanel(
    'Todavía no hay eventos confirmados vinculados a ${widget.entity.name}. No mostramos eventos sin una relación de datos real.',
  );

  Widget _mediaContent() {
    final hasMedia =
        _stories.isNotEmpty || _drops.isNotEmpty || _fancams.isNotEmpty;
    if (!hasMedia) {
      return _emptyPanel(
        'Todavía no hay multimedia etiquetada para ${widget.entity.name}.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_stories.isNotEmpty) ...[
          const _EntitySectionHeading(title: 'Stories etiquetadas'),
          const SizedBox(height: 8),
          ..._stories.map(_storyCard),
        ],
        if (_drops.isNotEmpty) ...[
          const _EntitySectionHeading(title: 'Drops'),
          const SizedBox(height: 8),
          ..._drops.map(_dropCard),
        ],
        if (_fancams.isNotEmpty) ...[
          const _EntitySectionHeading(title: 'Fancams'),
          const SizedBox(height: 8),
          ..._fancams.map(_fancamCard),
        ],
      ],
    );
  }

  Widget _emptyPanel(String message) =>
      _EntityEmpty(entity: widget.entity, message: message);

  Widget _newsCard(DiscoverNews item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SharedNewsPostCard(
        news: SharedNewsPostContent(
          title: item.displayTitle,
          source: item.displaySource,
          summary: item.cardSummary,
          articleUrl: item.directArticleUrl.isNotEmpty
              ? item.directArticleUrl
              : item.relatedResultsUrl,
          imageUrl: item.hasAuthorizedImage ? item.imageUrl : '',
          publishedLabel: item.publishedLabel,
        ),
      ),
    );
  }

  Widget _postCard(HubPost post) {
    final news = SharedNewsPostContent.fromCaption(post.caption).news;
    if (news != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SharedNewsPostCard(news: news),
          if (SharedNewsPostContent.fromCaption(
            post.caption,
          ).comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text(
                SharedNewsPostContent.fromCaption(post.caption).comment,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      );
    }
    return _EntityContentCard(
      key: ValueKey('entity-post-${post.id}'),
      title: post.caption.isEmpty
          ? 'Publicación de ${post.author}'
          : post.caption,
      subtitle: '${post.author} · ${post.username} · ${post.time}',
      badge: post.hasVideoMedia ? 'Video' : 'Publicación de fan',
      media: post.imageAsset,
      onTap: () {},
    );
  }

  Widget _storyCard(Story story) {
    return _EntityContentCard(
      title: story.title.isEmpty ? 'Story de ${story.name}' : story.title,
      subtitle: '${story.name} · ${story.timeLabel}',
      badge: 'Story',
      media: story.imageAsset,
      onTap: () {},
    );
  }

  Widget _dropCard(DropClip drop) {
    return _EntityContentCard(
      title: drop.caption.isEmpty ? drop.title : drop.caption,
      subtitle:
          '${drop.creatorName.isEmpty ? drop.creator : drop.creatorName} · Drop',
      badge: 'Ver Drop',
      media: drop.imageAsset,
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => DropsScreen(
              user: widget.currentUser,
              dropService: widget.dropService,
              followService: widget.followService,
              postService: widget.postService,
              chatService: widget.chatService,
              storyService: widget.storyService,
              fancamService: widget.fancamService,
              contentCategoryService: widget.contentCategoryService,
              userTagService: widget.userTagService,
              artistTagService: widget.artistTagService,
              initialDropId: drop.id,
              showBackButton: true,
            ),
          ),
        );
      },
    );
  }

  Widget _fancamCard(Fancam fancam) {
    return _EntityContentCard(
      title: fancam.caption.isEmpty ? fancam.title : fancam.caption,
      subtitle:
          '${fancam.creatorName.isEmpty ? fancam.creator : fancam.creatorName} · Fancam',
      badge: 'Ver Fancam',
      media: fancam.imageAsset,
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => FancamsScreen(
              user: widget.currentUser,
              fancamService: widget.fancamService,
              followService: widget.followService,
              postService: widget.postService,
              chatService: widget.chatService,
              storyService: widget.storyService,
              dropService: widget.dropService,
              contentCategoryService: widget.contentCategoryService,
              userTagService: widget.userTagService,
              artistTagService: widget.artistTagService,
              initialFancamId: fancam.id,
              showBackButton: true,
            ),
          ),
        );
      },
    );
  }
}

class _EntityHeader extends StatelessWidget {
  const _EntityHeader({
    required this.entity,
    required this.editorial,
    required this.following,
    required this.followBusy,
    required this.followerCount,
    required this.followerCountLoading,
    required this.onFollow,
  });

  final KpopEntity entity;
  final _EntityEditorialData editorial;
  final bool following;
  final bool followBusy;
  final int? followerCount;
  final bool followerCountLoading;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF070A13),
        border: Border(bottom: BorderSide(color: Color(0xFF23293A))),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: entity.imageUrl.trim().isEmpty
                ? const _EntityStageBackdrop()
                : Image.network(
                    entity.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _EntityStageBackdrop(),
                  ),
          ),
          const Positioned.fill(child: _EntityHeaderScrim()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 74, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _EntityMonogram(entity: entity),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entity.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (entity.verified) ...[
                                const SizedBox(width: 7),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppTheme.cyan,
                                  size: 21,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            entity.typeLabel,
                            style: const TextStyle(
                              color: AppTheme.rose,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _EntityFollowerCount(
                            loading: followerCountLoading,
                            count: followerCount,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.rose, AppTheme.violet],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.rose.withValues(alpha: .26),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: followBusy ? null : onFollow,
                          icon: Icon(
                            followBusy
                                ? Icons.hourglass_top_rounded
                                : following
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                          ),
                          label: Text(
                            followBusy
                                ? 'Guardando'
                                : following
                                ? 'Siguiendo'
                                : 'Seguir',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (editorial.fandom.isNotEmpty &&
                        editorial.debutYear.isNotEmpty)
                      _EntityInfoPill(
                        label: '${editorial.fandom} · ${editorial.debutYear}',
                      )
                    else
                      _EntityInfoPill(label: editorial.fandomLabel),
                    if (editorial.debutYear.isNotEmpty)
                      _EntityInfoPill(label: 'Debut ${editorial.debutYear}'),
                    if (editorial.agency.isNotEmpty)
                      _EntityInfoPill(label: editorial.agency),
                    if (editorial.country.isNotEmpty)
                      _EntityInfoPill(label: editorial.country),
                    if (editorial.groupName.isNotEmpty)
                      _EntityInfoPill(label: editorial.groupName),
                    if (editorial.role.isNotEmpty)
                      _EntityInfoPill(label: editorial.role),
                    _EntityInfoPill(
                      label: entity.verified ? 'Verificado' : 'Ficha base',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntityHeaderScrim extends StatelessWidget {
  const _EntityHeaderScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xCC050711),
            const Color(0x88050711),
            const Color(0xF5050711),
          ],
        ),
      ),
    );
  }
}

class _EntityImageCredit extends StatefulWidget {
  const _EntityImageCredit({required this.entity});

  final KpopEntity entity;

  @override
  State<_EntityImageCredit> createState() => _EntityImageCreditState();
}

class _EntityImageCreditState extends State<_EntityImageCredit> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (widget.entity.imageSource.trim().isNotEmpty)
        widget.entity.imageSource.trim(),
      if (widget.entity.imageLicense.trim().isNotEmpty)
        widget.entity.imageLicense.trim(),
      if (widget.entity.attribution.trim().isNotEmpty)
        widget.entity.attribution.trim(),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220).withValues(alpha: .86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: .18)),
      ),
      child: InkWell(
        key: const ValueKey('entity-image-credit'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_camera_back_outlined,
                    color: AppTheme.cyan,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Crédito de imagen',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white60,
                    size: 18,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 7),
                Text(
                  details.join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityMonogram extends StatelessWidget {
  const _EntityMonogram({required this.entity});

  final KpopEntity entity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.cyan, AppTheme.violet, AppTheme.rose],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF080B14),
        ),
        child: Center(
          child: Text(
            entity.name.isEmpty ? 'H' : entity.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EntityFollowerCount extends StatelessWidget {
  const _EntityFollowerCount({required this.loading, required this.count});

  final bool loading;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: 82,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(99),
        ),
      );
    }
    return Text(
      count == null ? '— seguidores' : formatKpopFollowerCount(count!),
      style: TextStyle(
        color: Colors.white.withValues(alpha: .7),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EntityStageBackdrop extends StatelessWidget {
  const _EntityStageBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EntityStagePainter());
  }
}

class _EntityStagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF090C19), Color(0xFF160A28), Color(0xFF07131D)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);
    final beams = <(Offset, Offset, Color)>[
      (
        Offset(size.width * .08, 0),
        Offset(size.width * .58, size.height * .72),
        AppTheme.violet,
      ),
      (
        Offset(size.width * .88, 0),
        Offset(size.width * .44, size.height * .66),
        AppTheme.rose,
      ),
      (
        Offset(size.width * .48, 0),
        Offset(size.width * .18, size.height * .58),
        AppTheme.cyan,
      ),
    ];
    for (final beam in beams) {
      canvas.drawLine(
        beam.$1,
        beam.$2,
        Paint()
          ..color = beam.$3.withValues(alpha: .22)
          ..strokeWidth = 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawLine(
      Offset(0, size.height * .37),
      Offset(size.width, size.height * .37),
      Paint()..color = Colors.white.withValues(alpha: .08),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EntityInfoPill extends StatelessWidget {
  const _EntityInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EntityBioSection extends StatelessWidget {
  const _EntityBioSection({required this.entity, required this.editorial});

  final KpopEntity entity;
  final _EntityEditorialData editorial;

  @override
  Widget build(BuildContext context) {
    final bio = editorial.bio.isNotEmpty ? editorial.bio : entity.bio;
    return _EntityInfoPanel(
      title: 'Biografía',
      icon: Icons.auto_stories_outlined,
      child: Text(
        bio.isEmpty
            ? 'Todavía no tenemos biografía completa para este artista.'
            : bio,
        style: _entityMutedStyle,
      ),
    );
  }
}

class _EntityMembersSection extends StatelessWidget {
  const _EntityMembersSection({
    required this.entity,
    required this.members,
    required this.memberProfiles,
    required this.onMember,
    required this.onMemberEntity,
  });

  final KpopEntity entity;
  final List<String> members;
  final List<KpopEntityMember> memberProfiles;
  final ValueChanged<String> onMember;
  final ValueChanged<KpopEntity> onMemberEntity;

  @override
  Widget build(BuildContext context) {
    return _EntityInfoPanel(
      title: 'Integrantes',
      icon: Icons.groups_2_outlined,
      child: members.isEmpty
          ? Text(
              'Pronto vamos a completar integrantes.',
              style: _entityMutedStyle,
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (memberProfiles.isNotEmpty)
                  for (final member in memberProfiles)
                    _memberTile(
                      member.displayName,
                      member.entity,
                      () => onMemberEntity(member.entity),
                    )
                else
                  for (final member in members)
                    _memberTile(member, null, () => onMember(member)),
              ],
            ),
    );
  }

  Widget _memberTile(String member, KpopEntity? profile, VoidCallback onTap) {
    return InkWell(
      key: ValueKey(
        'discover-idol-${_discoverWidgetKey(entity.name)}-${_discoverWidgetKey(member)}',
      ),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.violet, AppTheme.rose],
                ),
                border: Border.all(color: AppTheme.cyan.withValues(alpha: .55)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.violet.withValues(alpha: .24),
                    blurRadius: 12,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: profile?.imageUrl.trim().isNotEmpty == true
                  ? Image.network(
                      profile!.imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _memberInitial(member),
                    )
                  : _memberInitial(member),
            ),
            const SizedBox(height: 7),
            Text(
              member,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberInitial(String member) {
    return Text(
      member.isEmpty ? 'H' : member[0].toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EntityDiscographySection extends StatelessWidget {
  const _EntityDiscographySection({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _EntityInfoPanel(
      title: 'Discografía básica',
      icon: Icons.album_outlined,
      child: items.isEmpty
          ? Text(
              'Pronto vamos a completar discografía.',
              style: _entityMutedStyle,
            )
          : SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final colors = index.isEven
                      ? const [Color(0xFF8B5CF6), Color(0xFF111827)]
                      : const [Color(0xFFFF2D9A), Color(0xFF111827)];
                  return Container(
                    width: 104,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          color: AppTheme.cyan,
                          size: 20,
                        ),
                        Text(
                          item,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _EntityInfoPanel extends StatelessWidget {
  const _EntityInfoPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EntityTabs extends StatelessWidget {
  const _EntityTabs({
    required this.selected,
    required this.tabs,
    required this.counts,
    required this.onSelected,
  });

  final _EntityTab selected;
  final List<_EntityTab> tabs;
  final Map<_EntityTab, int> counts;
  final ValueChanged<_EntityTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('entity-tab-${tab.name}'),
                selected: selected == tab,
                onSelected: (_) => onSelected(tab),
                avatar: Icon(_icon(tab), size: 17),
                label: Text(_label(tab)),
              ),
            ),
        ],
      ),
    );
  }

  String _label(_EntityTab tab) {
    return switch (tab) {
      _EntityTab.home => 'Inicio',
      _EntityTab.info => 'Información',
      _EntityTab.members => 'Integrantes ${counts[tab] ?? 0}',
      _EntityTab.events => 'Eventos',
      _EntityTab.media => 'Multimedia · Drops',
    };
  }

  IconData _icon(_EntityTab tab) => switch (tab) {
    _EntityTab.home => Icons.home_rounded,
    _EntityTab.info => Icons.info_outline_rounded,
    _EntityTab.members => Icons.groups_2_outlined,
    _EntityTab.events => Icons.event_outlined,
    _EntityTab.media => Icons.perm_media_outlined,
  };
}

class _EntitySectionHeading extends StatelessWidget {
  const _EntitySectionHeading({required this.title, this.trailing = ''});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 23,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [AppTheme.cyan, AppTheme.rose],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .56),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _EntityContentCard extends StatelessWidget {
  const _EntityContentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.media,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 86,
                  height: 86,
                  color: AppTheme.violet.withValues(alpha: .25),
                  child: media.isEmpty
                      ? const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 34,
                        )
                      : Image.network(
                          media,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: const TextStyle(
                        color: AppTheme.cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .58),
                        fontWeight: FontWeight.w700,
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

class _EntityEmpty extends StatelessWidget {
  const _EntityEmpty({required this.entity, this.message});

  final KpopEntity entity;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.cyan),
          const SizedBox(height: 8),
          Text(
            message ??
                'Todavía no hay contenido etiquetado para ${entity.name}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .76),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntityLoading extends StatelessWidget {
  const _EntityLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EntityEditorialData {
  const _EntityEditorialData({
    this.bio = '',
    this.fandom = '',
    this.agency = '',
    this.country = '',
    this.role = '',
    this.groupName = '',
    this.members = const [],
    this.memberProfiles = const [],
    this.discography = const [],
    this.debutYear = '',
  });

  final String bio;
  final String fandom;
  final String agency;
  final String country;
  final String role;
  final String groupName;
  final List<String> members;
  final List<KpopEntityMember> memberProfiles;
  final List<String> discography;
  final String debutYear;

  String get fandomLabel => fandom.isEmpty ? 'Fandom por completar' : fandom;

  factory _EntityEditorialData.fromRow(
    Map<String, dynamic> row, {
    required _EntityEditorialData fallback,
  }) {
    return _EntityEditorialData(
      bio: _firstMeaningfulText([
        row['bio'],
        fallback.bio,
      ], rejectShortBio: true),
      fandom: _firstMeaningfulText([row['fandom_name'], fallback.fandom]),
      agency: _firstMeaningfulText([
        row['agency'],
        row['company'],
        fallback.agency,
      ]),
      country: _firstMeaningfulText([row['country'], fallback.country]),
      role: _firstMeaningfulText([row['role'], fallback.role]),
      groupName: _firstMeaningfulText([row['group_name'], fallback.groupName]),
      members: fallback.members,
      memberProfiles: fallback.memberProfiles,
      discography: fallback.discography,
      debutYear: _firstMeaningfulText([row['debut_year'], fallback.debutYear]),
    );
  }

  _EntityEditorialData withMemberProfiles(List<KpopEntityMember> profiles) {
    return _EntityEditorialData(
      bio: bio,
      fandom: fandom,
      agency: agency,
      country: country,
      role: role,
      groupName: groupName,
      members: profiles.map((item) => item.displayName).toList(growable: false),
      memberProfiles: profiles,
      discography: discography,
      debutYear: debutYear,
    );
  }

  factory _EntityEditorialData.forEntity(KpopEntity entity) {
    final local = _catalogEditorialForEntity(entity);
    final seed = _seedEditorialForName(entity.name);
    final entityBio = _firstMeaningfulText([entity.bio], rejectShortBio: true);
    return _EntityEditorialData(
      bio: _firstMeaningfulText([
        seed.bio,
        local.bio,
        entityBio,
      ], rejectShortBio: true),
      fandom: _firstMeaningfulText([local.fandom, seed.fandom]),
      agency: _firstMeaningfulText([local.agency, seed.agency]),
      country: _firstMeaningfulText([local.country, seed.country]),
      role: _firstMeaningfulText([local.role, seed.role]),
      groupName: _firstMeaningfulText([local.groupName, seed.groupName]),
      // The seed is the more complete temporary compatibility source. The
      // discover catalog can contain a shorter legacy member list.
      members: seed.members.isNotEmpty ? seed.members : local.members,
      discography: seed.discography.isNotEmpty
          ? seed.discography
          : local.discography,
      debutYear: _firstMeaningfulText([local.debutYear, seed.debutYear]),
    );
  }
}

_EntityEditorialData _catalogEditorialForEntity(KpopEntity entity) {
  final group = entity.type == KpopEntityType.group
      ? _findDiscoverGroup(entity)
      : null;
  if (group != null) {
    return _EntityEditorialData(
      bio: _firstMeaningfulText([
        group.bio,
        group.fullBio,
      ], rejectShortBio: true),
      fandom: group.fandom,
      agency: group.company,
      country: group.country,
      members: group.idols.map((idol) => idol.name).toList(growable: false),
      discography: _catalogDiscography(group),
      debutYear: group.debut,
    );
  }

  final idolMatch = _findDiscoverIdol(entity);
  if (idolMatch != null) {
    final idol = idolMatch.$1;
    final idolGroup = idolMatch.$2;
    return _EntityEditorialData(
      bio: _firstMeaningfulText([idol.bio, idol.fullBio], rejectShortBio: true),
      fandom: idolGroup.fandom,
      agency: idolGroup.company,
      country: _firstMeaningfulText([idol.country, idolGroup.country]),
      role: idol.role,
      groupName: idolGroup.name,
      discography: _catalogDiscography(idolGroup),
      debutYear: idolGroup.debut,
    );
  }

  return const _EntityEditorialData();
}

DiscoverGroup? _findDiscoverGroup(KpopEntity entity) {
  final keys = _entityLookupKeys(entity);
  for (final group in discoverGroups) {
    final groupKeys = {
      _compactEntityKey(group.id),
      _compactEntityKey(group.name),
      ...group.aliases.map(_compactEntityKey),
    }..remove('');
    if (keys.any(groupKeys.contains)) return group;
  }
  return null;
}

(DiscoverIdol, DiscoverGroup)? _findDiscoverIdol(KpopEntity entity) {
  final keys = _entityLookupKeys(entity);
  for (final group in discoverGroups) {
    for (final idol in group.idols) {
      final idolKeys = {
        _compactEntityKey(idol.id),
        _compactEntityKey(idol.name),
        _compactEntityKey(idol.realName),
        _compactEntityKey(idol.fullName),
        ...idol.aliases.map(_compactEntityKey),
      }..remove('');
      if (keys.any(idolKeys.contains)) return (idol, group);
    }
  }
  return null;
}

Set<String> _entityLookupKeys(KpopEntity entity) {
  return {
    _compactEntityKey(entity.id),
    _compactEntityKey(entity.name),
    _compactEntityKey(entity.normalizedName),
    ...entity.aliases.map(_compactEntityKey),
  }..remove('');
}

List<String> _catalogDiscography(DiscoverGroup group) {
  final items = <String>[...group.recommendedSongs, ...group.featuredEras];
  final seen = <String>{};
  return items
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && seen.add(item.toLowerCase()))
      .toList(growable: false);
}

_EntityEditorialData _seedEditorialForName(String name) {
  return _entityEditorialSeed[_normalizeEntityKey(name)] ??
      _entityEditorialSeed[_compactEntityKey(name)] ??
      const _EntityEditorialData();
}

String _firstMeaningfulText(
  Iterable<Object?> values, {
  bool rejectShortBio = false,
}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (!_isMeaningfulText(text, rejectShortBio: rejectShortBio)) continue;
    return text;
  }
  return '';
}

bool _isMeaningfulText(String value, {bool rejectShortBio = false}) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized.contains('por completar')) return false;
  if (normalized.contains('pronto vamos a completar')) return false;
  if (normalized == 'pendiente' ||
      normalized == 'pendiente de url autorizada') {
    return false;
  }
  if (rejectShortBio && normalized.length < 24) return false;
  return true;
}

String _normalizeEntityKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _compactEntityKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String _discoverWidgetKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

const _entityEditorialSeed = <String, _EntityEditorialData>{
  'bts': _EntityEditorialData(
    bio:
        'Grupo surcoreano con una carrera global marcada por pop, hip-hop, performance y una conexión muy fuerte con ARMY.',
    fandom: 'ARMY',
    debutYear: '2013',
    members: ['RM', 'Jin', 'SUGA', 'j-hope', 'Jimin', 'V', 'Jungkook'],
    discography: [
      '2 Cool 4 Skool',
      'Dark & Wild',
      'Wings',
      'Love Yourself',
      'Map of the Soul: 7',
      'BE',
      'Proof',
    ],
  ),
  'blackpink': _EntityEditorialData(
    bio:
        'Grupo con identidad visual fuerte, pop de alto impacto y presencia global en música, moda y performance.',
    fandom: 'BLINK',
    debutYear: '2016',
    members: ['Jisoo', 'Jennie', 'Rosé', 'Lisa'],
    discography: ['Square One', 'The Album', 'Born Pink'],
  ),
  'stray kids': _EntityEditorialData(
    bio:
        'Grupo reconocido por energía, producción propia y una comunidad STAY muy activa.',
    fandom: 'STAY',
    debutYear: '2018',
    members: [
      'Bang Chan',
      'Lee Know',
      'Changbin',
      'Hyunjin',
      'Han',
      'Felix',
      'Seungmin',
      'I.N',
    ],
    discography: ['I am NOT', 'GO LIVE', 'NOEASY', '5-STAR', 'ROCK-STAR'],
  ),
  'newjeans': _EntityEditorialData(
    bio:
        'Grupo con estética fresca, pop nostálgico y una forma moderna de conectar música, moda y cultura digital.',
    fandom: 'Bunnies',
    debutYear: '2022',
    members: ['Minji', 'Hanni', 'Danielle', 'Haerin', 'Hyein'],
    discography: ['New Jeans', 'OMG', 'Get Up', 'How Sweet'],
  ),
  'twice': _EntityEditorialData(
    bio:
        'Grupo de larga trayectoria, conocido por canciones pop brillantes y una comunidad ONCE internacional.',
    fandom: 'ONCE',
    debutYear: '2015',
    members: [
      'Nayeon',
      'Jeongyeon',
      'Momo',
      'Sana',
      'Jihyo',
      'Mina',
      'Dahyun',
      'Chaeyoung',
      'Tzuyu',
    ],
    discography: [
      'The Story Begins',
      'Twicetagram',
      'Eyes Wide Open',
      'Formula of Love',
      'Ready to Be',
    ],
  ),
  'seventeen': _EntityEditorialData(
    bio:
        'Grupo con foco en performance, producción y coreografías precisas, muy conectado con CARAT.',
    fandom: 'CARAT',
    debutYear: '2015',
    members: [
      'S.Coups',
      'Jeonghan',
      'Joshua',
      'Jun',
      'Hoshi',
      'Wonwoo',
      'Woozi',
      'DK',
      'Mingyu',
      'The8',
      'Seungkwan',
      'Vernon',
      'Dino',
    ],
    discography: ['17 Carat', 'Teen, Age', 'An Ode', 'Face the Sun', 'FML'],
  ),
  'enhypen': _EntityEditorialData(
    bio:
        'Grupo con narrativa visual intensa, performance cuidada y fandom global en crecimiento.',
    fandom: 'ENGENE',
    debutYear: '2020',
    members: [
      'Jungwon',
      'Heeseung',
      'Jay',
      'Jake',
      'Sunghoon',
      'Sunoo',
      'Ni-ki',
    ],
    discography: [
      'Border: Day One',
      'Dimension: Dilemma',
      'Manifesto: Day 1',
      'Orange Blood',
    ],
  ),
  'txt': _EntityEditorialData(
    bio:
        'Grupo con concepto juvenil, narrativa pop y estética visual cambiante.',
    fandom: 'MOA',
    debutYear: '2019',
    members: ['Soobin', 'Yeonjun', 'Beomgyu', 'Taehyun', 'Huening Kai'],
    discography: [
      'The Dream Chapter: Star',
      'The Chaos Chapter: Freeze',
      'minisode 2',
      'The Name Chapter: Temptation',
    ],
  ),
  'ive': _EntityEditorialData(
    bio:
        'Grupo con pop elegante, presencia escénica marcada y una estética visual refinada.',
    fandom: 'DIVE',
    debutYear: '2021',
    members: ['Yujin', 'Gaeul', 'Rei', 'Wonyoung', 'Liz', 'Leeseo'],
    discography: [
      'Eleven',
      'Love Dive',
      'After Like',
      "I've IVE",
      'Ive Switch',
    ],
  ),
  'le sserafim': _EntityEditorialData(
    bio:
        'Grupo con concepto de confianza, performance potente y sonido pop moderno.',
    fandom: 'FEARNOT',
    debutYear: '2022',
    members: ['Sakura', 'Chaewon', 'Yunjin', 'Kazuha', 'Eunchae'],
    discography: ['Fearless', 'Antifragile', 'Unforgiven', 'Easy'],
  ),
  'aespa': _EntityEditorialData(
    bio:
        'Grupo con identidad futurista, elementos digitales y sonido pop electrónico.',
    fandom: 'MY',
    debutYear: '2020',
    members: ['Karina', 'Giselle', 'Winter', 'Ningning'],
    discography: ['Savage', 'Girls', 'Drama', 'Armageddon'],
  ),
  'nct': _EntityEditorialData(
    bio:
        'Proyecto con múltiples unidades, estilos y una comunidad internacional amplia.',
    fandom: 'NCTzen',
    debutYear: '2016',
    members: ['NCT 127', 'NCT DREAM', 'WayV', 'NCT WISH'],
    discography: ['NCT 2018 Empathy', 'Resonance', 'Universe', 'Golden Age'],
  ),
  'ateez': _EntityEditorialData(
    bio:
        'Grupo conocido por performance intensa, narrativa aventurera y energía escénica.',
    fandom: 'ATINY',
    debutYear: '2018',
    members: [
      'Hongjoong',
      'Seonghwa',
      'Yunho',
      'Yeosang',
      'San',
      'Mingi',
      'Wooyoung',
      'Jongho',
    ],
    discography: [
      'Treasure EP.1',
      'Zero: Fever Part.1',
      'The World EP.1',
      'Golden Hour',
    ],
  ),
  'exo': _EntityEditorialData(
    bio:
        'Grupo con trayectoria destacada, voces fuertes y alto impacto en la historia moderna del K-pop.',
    fandom: 'EXO-L',
    debutYear: '2012',
    members: [
      'Xiumin',
      'Suho',
      'Lay',
      'Baekhyun',
      'Chen',
      'Chanyeol',
      'D.O.',
      'Kai',
      'Sehun',
    ],
    discography: [
      'XOXO',
      'Exodus',
      'The War',
      'Don’t Mess Up My Tempo',
      'Exist',
    ],
  ),
  'jungkook': _EntityEditorialData(
    bio:
        'Artista e integrante de BTS destacado por su voz, performance y carrera solista global.',
    fandom: 'ARMY',
    debutYear: '2013',
    discography: ['Seven', '3D', 'Golden'],
  ),
  'jimin': _EntityEditorialData(
    bio:
        'Artista e integrante de BTS reconocido por danza expresiva, tono vocal y presencia escénica.',
    fandom: 'ARMY',
    debutYear: '2013',
    discography: ['Face', 'Like Crazy', 'Muse'],
  ),
  'lisa': _EntityEditorialData(
    bio:
        'Artista e integrante de BLACKPINK reconocida por baile, carisma escénico y alcance global.',
    fandom: 'BLINK',
    debutYear: '2016',
    discography: ['Lalisa', 'Money', 'Rockstar'],
  ),
  'jennie': _EntityEditorialData(
    bio:
        'Artista e integrante de BLACKPINK con identidad musical, visual y de performance propia.',
    fandom: 'BLINK',
    debutYear: '2016',
    discography: ['Solo', 'You & Me'],
  ),
  'bang chan': _EntityEditorialData(
    bio:
        'Artista e integrante de Stray Kids asociado a liderazgo, producción y conexión cercana con fans.',
    fandom: 'STAY',
    debutYear: '2018',
    discography: ['SKZ-Player', 'Mixtape', '3RACHA'],
  ),
};

final _entityMutedStyle = TextStyle(
  color: Colors.white.withValues(alpha: .72),
  height: 1.35,
  fontWeight: FontWeight.w700,
);
