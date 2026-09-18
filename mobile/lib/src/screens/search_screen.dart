import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/demo_data.dart';
import '../data/discover_data.dart';
import '../models.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/local_story_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/kpop_entity_follow_service.dart';
import '../services/news_service.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/kpop_follower_count_formatter.dart';
import '../utils/community_membership_sections.dart';
import '../widgets/community_chat_message_tile.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/licensed_discover_visual.dart';
import '../widgets/premium_form_shell.dart';
import '../widgets/shared_news_post_card.dart';
import '../widgets/safety_report_sheet.dart';
import 'discover_detail_screens.dart';
import 'kpop_entity_profile_screen.dart';
import 'post_editor_screen.dart';
import 'public_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.user,
    this.followService = const LocalFollowService(),
    this.chatService = const LocalChatService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.artistTagService = const LocalArtistTagService(),
    this.userTagService = const LocalUserTagService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.resetSignal = 0,
    this.initialSection,
    this.sectionRequestSignal = 0,
  });

  final AuthUser? user;
  final LocalFollowService followService;
  final LocalChatService chatService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalContentCategoryService contentCategoryService;
  final LocalArtistTagService artistTagService;
  final LocalUserTagService userTagService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;
  final int resetSignal;
  final DiscoverSection? initialSection;
  final int sectionRequestSignal;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  DiscoverSection _section = DiscoverSection.all;
  String _newsArtist = 'Todos';
  String _newsCategory = 'Para vos';
  String _newsTopicQuery = '';
  String _entityRegion = 'Todos';
  DiscoverEntityType? _entityType;
  final _scrollController = ScrollController();
  final _followingProfiles = <String>{};
  final _profiles = <CommunityProfile>[];
  final _communityEntitySuggestions = <DiscoverArtistEntity>[];
  final _createdCommunities = <DiscoverCommunity>[];
  final _kpopEntities = <KpopEntity>[];
  final _entitySuggestions = <KpopEntity>[];
  int? _kpopGroupCount;
  int? _kpopArtistIdolCount;
  int? _kpopTotalCount;
  bool _entitySuggestionsLoading = false;
  bool _entitySuggestionsNoMatch = false;
  final _followedEntityIds = <String>{};
  final _kpopEntityFollowerCounts = <String, int>{};
  final _entityFollowBusyIds = <String>{};
  final _realCommunities = <DiscoverCommunity>[];
  final _joinedCommunityIds = <String>{};
  final _fanEvents = <_FanEvent>[];
  final _attendingEventIds = <String>{};
  final _kpopQuestions = <_KpopQuestion>[];
  final _realNews = <DiscoverNews>[];
  int _profileSearchEpoch = 0;
  int _entitySuggestionEpoch = 0;
  int _entityCountLoadEpoch = 0;
  Timer? _entitySuggestionDebounce;
  _DiscoverRealStats _realStats = const _DiscoverRealStats();
  bool _entityFollowerCountsLoading = true;
  bool _sharingNews = false;
  bool _newsTopicsSaving = false;
  bool _newsLoading = false;
  String? _newsError;

  bool get _isBetaReal => widget.followService.usesRealProfiles;
  final _exploreCommunitiesKey = GlobalKey();
  final _discoverCommunitiesKey = GlobalKey();

  String _normalized(String value) => value.toLowerCase().trim();

  bool _matches(String source) {
    final query = _normalized(_query);
    return query.isEmpty || _normalized(source).contains(query);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) _section = widget.initialSection!;
    LocalFollowService.revision.addListener(_reloadFollowing);
    _restoreFollowing();
    if (_isBetaReal) {
      _newsLoading = true;
      _restoreRealStats();
      _restoreRealDiscoverData();
      _restoreRealNews();
    }
  }

  @override
  void dispose() {
    LocalFollowService.revision.removeListener(_reloadFollowing);
    _entitySuggestionDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _reloadFollowing() {
    _restoreFollowing();
    if (_isBetaReal) {
      _restoreRealStats();
      _restoreRealDiscoverData();
      _restoreRealNews();
    }
  }

  Future<void> _restoreFollowing() async {
    var following = <String>{};
    var profiles = <CommunityProfile>[];
    try {
      following = await widget.followService.restoreFollowingIds();
    } catch (error) {
      debugPrint('PROFILE_SEARCH_ERROR followingIds error=$error');
    }
    try {
      profiles = await widget.followService.restoreProfiles(limit: 500);
    } catch (error) {
      debugPrint('PROFILE_SEARCH_ERROR restoreProfiles error=$error');
    }
    if (!mounted) return;
    setState(() {
      _followingProfiles
        ..clear()
        ..addAll(following);
      _profiles
        ..clear()
        ..addAll(profiles);
    });
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) _resetToTop();
    if (oldWidget.sectionRequestSignal != widget.sectionRequestSignal &&
        widget.initialSection != null) {
      _selectSection(widget.initialSection!);
    }
    if (!oldWidget.followService.usesRealProfiles && _isBetaReal) {
      _restoreRealStats();
      _restoreRealDiscoverData();
      _restoreRealNews();
    }
  }

  Future<void> _restoreRealNews() async {
    if (mounted) {
      setState(() {
        _newsLoading = true;
        _newsError = null;
      });
    }
    try {
      final news = await SupabaseNewsService().restoreNews();
      if (!mounted) return;
      setState(() {
        _realNews
          ..clear()
          ..addAll(news);
        _newsLoading = false;
      });
      debugPrint('NEWS_FETCH_OK count=${news.length}');
    } on NewsServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _realNews.clear();
        _newsLoading = false;
        _newsError = error.message;
      });
    } catch (error) {
      debugPrint('NEWS_FETCH_ERROR screen=$error');
      if (!mounted) return;
      setState(() {
        _realNews.clear();
        _newsLoading = false;
        _newsError = 'No pudimos cargar las noticias en este momento.';
      });
    }
  }

  Future<void> _restoreRealDiscoverData() async {
    final client = supabase.Supabase.instance.client;
    final results = await Future.wait<Object?>([
      _restoreKpopEntities(),
      _restoreKpopEntityCounts(client),
      _restoreFollowedEntityIds(client),
      _restoreCommunities(client),
      _restoreJoinedCommunityIds(client),
      _restoreFanEvents(client),
      _restoreAttendingEventIds(client),
      _restoreKpopQuestions(client),
    ]);
    if (!mounted) return;
    final entities = results[0] as List<KpopEntity>;
    final entityCounts = results[1] as _KpopEntityCounts?;
    setState(() {
      _kpopEntities
        ..clear()
        ..addAll(entities);
      _followedEntityIds
        ..clear()
        ..addAll(results[2] as Set<String>);
      _realCommunities
        ..clear()
        ..addAll(results[3] as List<DiscoverCommunity>);
      _joinedCommunityIds
        ..clear()
        ..addAll(results[4] as Set<String>);
      _fanEvents
        ..clear()
        ..addAll(results[5] as List<_FanEvent>);
      _attendingEventIds
        ..clear()
        ..addAll(results[6] as Set<String>);
      _kpopQuestions
        ..clear()
        ..addAll(results[7] as List<_KpopQuestion>);
      _kpopEntityFollowerCounts.clear();
      _entityFollowerCountsLoading = true;
      _kpopGroupCount = entityCounts?.groups;
      _kpopArtistIdolCount = entityCounts?.artistsAndIdols;
      _kpopTotalCount = entityCounts?.total;
    });
    assert(_kpopCountsAreConsistent);
    await _restoreKpopEntityFollowerCounts(entities);
  }

  bool get _kpopCountsAreConsistent {
    final groups = _kpopGroupCount;
    final artistsAndIdols = _kpopArtistIdolCount;
    final total = _kpopTotalCount;
    return groups == null ||
        artistsAndIdols == null ||
        total == null ||
        groups + artistsAndIdols == total;
  }

  Future<_KpopEntityCounts?> _restoreKpopEntityCounts(
    supabase.SupabaseClient client,
  ) async {
    try {
      final counts = await Future.wait<int>([
        _countKpopEntities(client, const ['group']),
        _countKpopEntities(client, const ['artist', 'idol']),
        _countKpopEntities(client, const ['group', 'artist', 'idol']),
      ]);
      return _KpopEntityCounts(
        groups: counts[0],
        artistsAndIdols: counts[1],
        total: counts[2],
      );
    } catch (error) {
      debugPrint('DISCOVER_KPOP_COUNT_ERROR error=$error');
      return null;
    }
  }

  Future<int> _countKpopEntities(
    supabase.SupabaseClient client,
    List<String> types,
  ) async {
    return await client
        .from('kpop_entities')
        .count(supabase.CountOption.exact)
        .inFilter('entity_type', types);
  }

  Future<List<KpopEntity>> _restoreKpopEntities() async {
    try {
      final entities = await widget.artistTagService.searchEntities(limit: 80);
      if (entities.isNotEmpty && widget.artistTagService.usesRealArtistTags) {
        return entities;
      }
      if (entities.isNotEmpty && !_isBetaReal) return entities;
    } catch (error) {
      debugPrint('DISCOVER_KPOP_CATALOG_ERROR real error=$error');
    }
    if (_isBetaReal) return const [];
    try {
      return await const LocalArtistTagService().searchEntities(limit: 80);
    } catch (error) {
      debugPrint('DISCOVER_KPOP_CATALOG_ERROR local error=$error');
      return const [];
    }
  }

  Future<void> _restoreKpopEntityFollowerCounts(
    Iterable<KpopEntity> entities,
  ) async {
    final epoch = ++_entityCountLoadEpoch;
    final ids = entities
        .map((entity) => entity.id)
        .where(_looksLikeUuid)
        .toList(growable: false);
    if (ids.isEmpty) {
      if (!mounted || epoch != _entityCountLoadEpoch) return;
      setState(() {
        _kpopEntityFollowerCounts.clear();
        _entityFollowerCountsLoading = false;
      });
      return;
    }
    try {
      final counts = await KpopEntityFollowService(
        supabase.Supabase.instance.client,
      ).restoreFollowerCounts(ids);
      if (!mounted || epoch != _entityCountLoadEpoch) return;
      setState(() {
        _kpopEntityFollowerCounts
          ..clear()
          ..addAll(counts);
        _entityFollowerCountsLoading = false;
      });
    } catch (error) {
      debugPrint('DISCOVER_ENTITY_FOLLOWER_COUNTS_ERROR $error');
      if (!mounted || epoch != _entityCountLoadEpoch) return;
      setState(() {
        _kpopEntityFollowerCounts.clear();
        _entityFollowerCountsLoading = false;
      });
    }
  }

  Future<Set<String>> _restoreFollowedEntityIds(
    supabase.SupabaseClient client,
  ) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return <String>{};
    try {
      final rows = await client
          .from('kpop_entity_follows')
          .select('entity_id')
          .eq('user_id', authUser.id);
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) => row['entity_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('DISCOVER_ENTITY_FOLLOWS_ERROR $error');
      return <String>{};
    }
  }

  Future<List<DiscoverCommunity>> _restoreCommunities(
    supabase.SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('communities')
          .select(
            'id,owner_id,name,country,region,city,fandom,description,privacy,status',
          )
          .eq('status', 'active')
          .order('name', ascending: true);
      final countRows = await client
          .from('community_members')
          .select('community_id');
      final counts = <String, int>{};
      for (final row in countRows.cast<Map<String, dynamic>>()) {
        final id = row['community_id'] as String? ?? '';
        if (id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) => _communityFromRow(row, counts))
          .toList(growable: false);
    } catch (error) {
      debugPrint('DISCOVER_COMMUNITIES_ERROR $error');
      return const <DiscoverCommunity>[];
    }
  }

  DiscoverCommunity _communityFromRow(
    Map<String, dynamic> row,
    Map<String, int> counts,
  ) {
    final id = row['id'] as String? ?? '';
    final country = row['country'] as String? ?? '';
    final region = row['region'] as String? ?? '';
    final city = row['city'] as String? ?? '';
    final displayRegion = [
      if (city.isNotEmpty) city,
      if (region.isNotEmpty) region,
      if (country.isNotEmpty) country,
    ].join(', ');
    return DiscoverCommunity(
      id: id,
      name: row['name'] as String? ?? 'Comunidad Hallyu',
      region: displayRegion.isEmpty ? 'Latam' : displayRegion,
      members: '${counts[id] ?? 0}',
      activity: 'Comunidad real',
      fandom: row['fandom'] as String? ?? 'Multi fandom',
      description: row['description'] as String? ?? '',
      posts: const [],
      country: country,
      province: region,
      city: city,
      privacy: (row['privacy'] as String? ?? 'public') == 'private'
          ? 'Privada'
          : 'Pública',
      createdBy: row['owner_id'] as String? ?? '',
    );
  }

  Future<Set<String>> _restoreJoinedCommunityIds(
    supabase.SupabaseClient client,
  ) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return <String>{};
    try {
      final rows = await client
          .from('community_members')
          .select('community_id')
          .eq('user_id', authUser.id);
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) => row['community_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('DISCOVER_JOINED_COMMUNITIES_ERROR $error');
      return <String>{};
    }
  }

  Future<List<_FanEvent>> _restoreFanEvents(
    supabase.SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('fan_events')
          .select(
            'id,title,fandom,country,city,place,starts_at,description,'
            'organizer_contact,external_link,category,status,created_at',
          )
          .eq('status', 'published')
          .order('starts_at', ascending: true);
      return rows
          .cast<Map<String, dynamic>>()
          .map(_FanEvent.fromRow)
          .toList(growable: false);
    } catch (error) {
      debugPrint('DISCOVER_FAN_EVENTS_ERROR $error');
      return const [];
    }
  }

  Future<Set<String>> _restoreAttendingEventIds(
    supabase.SupabaseClient client,
  ) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return <String>{};
    try {
      final rows = await client
          .from('fan_event_attendees')
          .select('event_id')
          .eq('user_id', authUser.id);
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) => row['event_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('DISCOVER_FAN_EVENT_ATTENDEES_ERROR $error');
      return <String>{};
    }
  }

  Future<List<_KpopQuestion>> _restoreKpopQuestions(
    supabase.SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('kpop101_questions')
          .select('id,title,detail,author_id,status,created_at')
          .order('created_at', ascending: false)
          .limit(30);
      return rows
          .cast<Map<String, dynamic>>()
          .map(_KpopQuestion.fromRow)
          .toList(growable: false);
    } catch (error) {
      debugPrint('DISCOVER_KPOP101_QUESTIONS_ERROR $error');
      return const [];
    }
  }

  Future<void> _restoreRealStats() async {
    final client = supabase.Supabase.instance.client;
    final globalStats = await _restoreGlobalExploreStats(client);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toUtc();
    final stats = _DiscoverRealStats(
      betaFans:
          globalStats?.betaFans ?? await _restoreApprovedBetaCount(client),
      eventCount:
          globalStats?.eventCount ??
          await _safeCount(
            client,
            table: 'fan_events',
            equals: const {'status': 'published'},
            fallbackToUnfiltered: true,
          ),
      dropsToday:
          globalStats?.dropsToday ??
          await _safeCount(
            client,
            table: 'drops',
            equals: const {'status': 'published'},
            gteColumn: 'created_at',
            gteValue: todayStart.toIso8601String(),
          ),
      communityMembers:
          globalStats?.communityMembers ??
          await _safeCount(
            client,
            table: 'community_members',
            missingTableValue: 0,
          ),
      verifiedStores:
          globalStats?.verifiedStores ??
          await _safeCount(client, table: 'verified_stores') ??
          await _safeCount(
            client,
            table: 'stores',
            equals: const {'verified': true},
          ) ??
          await _safeCount(
            client,
            table: 'stores',
            equals: const {'is_verified': true},
          ) ??
          await _safeCount(
            client,
            table: 'shops',
            equals: const {'verified': true},
          ) ??
          await _safeCount(
            client,
            table: 'shops',
            equals: const {'is_verified': true},
          ),
      kpopQuestions:
          globalStats?.kpopQuestions ??
          await _safeCount(client, table: 'kpop101_questions'),
    );
    if (!mounted) return;
    setState(() => _realStats = stats);
  }

  Future<_DiscoverRealStats?> _restoreGlobalExploreStats(
    supabase.SupabaseClient client,
  ) async {
    try {
      final response = await client.rpc('get_explore_global_stats');
      final row = _firstRow(response);
      if (row == null) return null;
      debugPrint('DISCOVER_GLOBAL_STATS_OK data=$row');
      return _DiscoverRealStats(
        betaFans: _intFrom(row['total_beta_fans'] ?? row['beta_fans']),
        eventCount: _intFrom(row['total_events'] ?? row['event_count']),
        dropsToday: _intFrom(row['total_drops_today'] ?? row['drops_today']),
        communityMembers: _intFrom(
          row['total_community_members'] ?? row['community_members'],
        ),
        verifiedStores: _intFrom(
          row['total_verified_stores'] ?? row['verified_stores'],
        ),
        kpopQuestions: _intFrom(
          row['total_kpop_questions'] ?? row['kpop_questions'],
        ),
      );
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'DISCOVER_GLOBAL_STATS_ERROR code=${error.code} message=${error.message}',
      );
      return null;
    } catch (error) {
      debugPrint('DISCOVER_GLOBAL_STATS_ERROR error=$error');
      return null;
    }
  }

  Future<int?> _restoreApprovedBetaCount(supabase.SupabaseClient client) async {
    try {
      final response = await client.rpc('claim_beta_access');
      final row = _firstRow(response);
      final rpcCount = _intFrom(row?['approved_count']);
      if (rpcCount != null && rpcCount > 0) return rpcCount;
    } catch (error) {
      debugPrint(
        'DISCOVER_COUNTER_ERROR source=claim_beta_access error=$error',
      );
    }

    return await _safeCount(client, table: 'profiles');
  }

  Future<int?> _safeCount(
    supabase.SupabaseClient client, {
    required String table,
    Map<String, Object?> equals = const {},
    String? gteColumn,
    String? gteValue,
    bool fallbackToUnfiltered = false,
    int? missingTableValue,
  }) async {
    try {
      return await _countQuery(
        client,
        table: table,
        equals: equals,
        gteColumn: gteColumn,
        gteValue: gteValue,
      );
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'DISCOVER_COUNTER_ERROR table=$table code=${error.code} message=${error.message}',
      );
      if (fallbackToUnfiltered && equals.isNotEmpty) {
        try {
          return await _countQuery(
            client,
            table: table,
            gteColumn: gteColumn,
            gteValue: gteValue,
          );
        } catch (fallbackError) {
          debugPrint(
            'DISCOVER_COUNTER_ERROR table=$table fallback=$fallbackError',
          );
        }
      }
      if (error.code == '42P01') return missingTableValue;
      return null;
    } catch (error) {
      debugPrint('DISCOVER_COUNTER_ERROR table=$table error=$error');
      return null;
    }
  }

  Future<int> _countQuery(
    supabase.SupabaseClient client, {
    required String table,
    Map<String, Object?> equals = const {},
    String? gteColumn,
    String? gteValue,
  }) async {
    dynamic query = client.from(table).count();
    for (final entry in equals.entries) {
      query = query.eq(entry.key, entry.value);
    }
    if (gteColumn != null && gteValue != null) {
      query = query.gte(gteColumn, gteValue);
    }
    final count = await query;
    return count as int;
  }

  Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final row = response.first;
      if (row is Map) return row.cast<String, dynamic>();
    }
    if (response is Map) return response.cast<String, dynamic>();
    return null;
  }

  int? _intFrom(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _resetToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _selectSection(DiscoverSection section) {
    setState(() => _section = section);
    _scheduleEntitySuggestions(_query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _scheduleEntitySuggestions(value);
    if (!widget.followService.usesRealProfiles) return;
    final query = value.trim();
    if (query.length < 2) return;
    _searchRealProfiles(query);
  }

  void _scheduleEntitySuggestions(String value) {
    _entitySuggestionDebounce?.cancel();
    final query = value.trim();
    final epoch = ++_entitySuggestionEpoch;
    if (query.length < 3 ||
        (_isBetaReal && !widget.artistTagService.usesRealArtistTags)) {
      setState(() {
        _entitySuggestions.clear();
        _entitySuggestionsLoading = false;
        _entitySuggestionsNoMatch = false;
      });
      return;
    }
    setState(() {
      _entitySuggestionsLoading = true;
      _entitySuggestionsNoMatch = false;
    });
    _entitySuggestionDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _restoreEntitySuggestions(query, epoch),
    );
  }

  Future<void> _restoreEntitySuggestions(String query, int epoch) async {
    try {
      final entities = await widget.artistTagService.searchEntities(
        // Fetch the live catalog, then apply the same complete matching
        // locally so editorial agency/fandom metadata participates without
        // requiring unsupported columns in public.kpop_entities.
        limit: 80,
      );
      if (!mounted || epoch != _entitySuggestionEpoch) return;
      final normalizedQuery = _normalized(query);
      final filtered =
          entities
              .where(_matchesEntitySection)
              .where(
                (entity) => _normalized(
                  '${entity.searchableText} ${_editorialSearchText(entity)}',
                ).contains(normalizedQuery),
              )
              .toList()
            ..sort(
              (a, b) => _entitySuggestionRank(
                a,
                query,
              ).compareTo(_entitySuggestionRank(b, query)),
            );
      setState(() {
        _entitySuggestions
          ..clear()
          ..addAll(filtered.take(8));
        _entitySuggestionsLoading = false;
        _entitySuggestionsNoMatch = filtered.isEmpty;
      });
    } catch (error) {
      if (!mounted || epoch != _entitySuggestionEpoch) return;
      setState(() {
        _entitySuggestions.clear();
        _entitySuggestionsLoading = false;
        _entitySuggestionsNoMatch = false;
      });
      debugPrint('DISCOVER_KPOP_SUGGESTIONS_ERROR error=$error');
    }
  }

  bool _matchesEntitySection(KpopEntity entity) {
    return switch (_section) {
      DiscoverSection.groups => entity.type == KpopEntityType.group,
      DiscoverSection.idols => entity.type != KpopEntityType.group,
      _ => true,
    };
  }

  int _entitySuggestionRank(KpopEntity entity, String query) {
    final normalizedQuery = _normalized(query);
    final name = _normalized(entity.name);
    final normalizedName = _normalized(entity.normalizedName);
    final aliases = entity.aliases.map(_normalized);
    if (name == normalizedQuery) return 0;
    if (name.startsWith(normalizedQuery)) return 1;
    if (normalizedName.startsWith(normalizedQuery)) return 2;
    if (aliases.any((alias) => alias.startsWith(normalizedQuery))) return 3;
    if (_normalized(_editorialSearchText(entity)).contains(normalizedQuery)) {
      return 4;
    }
    return 5;
  }

  Future<void> _searchRealProfiles(String query) async {
    final epoch = ++_profileSearchEpoch;
    try {
      final profiles = await widget.followService.restoreProfiles(
        query: query,
        limit: 80,
      );
      if (!mounted || epoch != _profileSearchEpoch) return;
      setState(() {
        _profiles
          ..clear()
          ..addAll(profiles);
      });
    } catch (error) {
      debugPrint('PROFILE_OPEN_ERROR searchProfiles query=$query error=$error');
    }
  }

  void _openPage(String title, Widget child) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DiscoverPage(title: title, child: child),
      ),
    );
  }

  void _openNews(DiscoverNews item) {
    _openPage(
      item.title,
      NewsDetailScreen(
        item: item,
        onShareToPost: () {
          _shareNewsAsPost(item);
        },
      ),
    );
  }

  Future<void> _shareNewsAsPost(DiscoverNews item) async {
    if (_sharingNews) return;
    final user = widget.user;
    if (user == null) {
      _showSnack('Iniciá sesión para compartir esta noticia.');
      return;
    }
    final articleUrl = item.directArticleUrl;
    if (articleUrl.isEmpty) {
      _showSnack(
        'Esta noticia todavía no tiene un enlace directo para compartir.',
      );
      return;
    }
    final relatedEntities = _entitiesForNews(item);
    final initialDraft = PostDraft(
      caption: '',
      tags: const ['#NoticiasKpop'],
      taggedEntities: relatedEntities,
      artist: item.entityLabel,
    );
    final draft = await Navigator.of(context).push<PostDraft>(
      MaterialPageRoute<PostDraft>(
        fullscreenDialog: true,
        builder: (context) => PostEditorScreen(
          initialDraft: initialDraft,
          currentUser: user,
          followService: widget.followService,
          artistTagService: widget.artistTagService,
          allowDemoMedia: !widget.postService.usesRealPosts,
          allowEmptyCaptionForNews: true,
        ),
      ),
    );
    if (!mounted || draft == null) return;
    final sharedDraft = draft.copyWith(
      caption: SharedNewsPostContent(
        title: item.displayTitle,
        source: item.displaySource,
        summary: item.cardSummary,
        articleUrl: articleUrl,
        imageUrl: item.hasAuthorizedImage ? item.imageUrl.trim() : '',
      ).attachToComment(draft.caption),
    );
    setState(() => _sharingNews = true);
    _showUploadStatus('Publicando noticia...');
    try {
      final post = await widget.postService.publish(
        author: user,
        draft: sharedDraft,
      );
      final metadataSaved = await _saveSharedNewsMetadata(
        post: post,
        draft: draft,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(
        metadataSaved
            ? 'La noticia se compartió en una publicación.'
            : 'La noticia se publicó, pero alguna etiqueta no pudo guardarse.',
      );
    } on PostServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(error.message);
    } catch (error) {
      debugPrint('NEWS_SHARE_POST_ERROR $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack('No pudimos compartir la noticia. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _sharingNews = false);
    }
  }

  List<KpopEntity> _entitiesForNews(DiscoverNews item) {
    final entityIds = item.relatedEntityIds.toSet();
    final lookupKeys = <String>{
      _compactKpopKey(item.artist),
      ...item.relatedGroups.map(_compactKpopKey),
      ...item.relatedArtists.map(_compactKpopKey),
      ...item.detectedEntityTags.map(_compactKpopKey),
    }..remove('');
    return _kpopEntities
        .where(
          (entity) =>
              entityIds.contains(entity.id) ||
              _kpopEntityLookupKeys(entity).any(lookupKeys.contains),
        )
        .take(LocalArtistTagService.maxTaggedEntitiesPerContent)
        .toList(growable: false);
  }

  Future<bool> _saveSharedNewsMetadata({
    required HubPost post,
    required PostDraft draft,
  }) async {
    var saved = true;
    if (draft.taggedEntities.isNotEmpty) {
      try {
        await widget.artistTagService.saveContentArtistTags(
          contentType: ProfileContentType.post,
          contentId: post.id,
          entities: draft.taggedEntities,
        );
      } catch (error) {
        saved = false;
        debugPrint('NEWS_SHARE_ARTIST_TAGS_ERROR ${post.id} $error');
      }
    }
    if (draft.taggedUsers.isNotEmpty) {
      try {
        await widget.userTagService.saveContentUserTags(
          contentType: ProfileContentType.post,
          contentId: post.id,
          taggedUsers: draft.taggedUsers,
        );
      } catch (error) {
        saved = false;
        debugPrint('NEWS_SHARE_USER_TAGS_ERROR ${post.id} $error');
      }
    }
    if (draft.profileCategories.isNotEmpty) {
      try {
        await widget.contentCategoryService.saveContentCategories(
          userId: post.authorId,
          contentType: ProfileContentType.post,
          contentId: post.id,
          categories: draft.profileCategories,
        );
      } catch (error) {
        saved = false;
        debugPrint('NEWS_SHARE_CATEGORIES_ERROR ${post.id} $error');
      }
    }
    return saved;
  }

  void _showUploadStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(minutes: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Text(message),
            ],
          ),
        ),
      );
  }

  void _openGroup(DiscoverGroup group) {
    _openPage(
      group.name,
      GroupDetailScreen(
        group: group,
        user: widget.user,
        fancamService: widget.fancamService,
        followService: widget.followService,
        postService: widget.postService,
        storyService: widget.storyService,
        dropService: widget.dropService,
        chatService: widget.chatService,
      ),
    );
  }

  void _openIdol(DiscoverIdol idol) {
    final group = discoverGroups.firstWhere((item) => item.id == idol.groupId);
    _openPage(
      idol.name,
      IdolDetailScreen(
        group: group,
        idol: idol,
        user: widget.user,
        fancamService: widget.fancamService,
        followService: widget.followService,
        postService: widget.postService,
        storyService: widget.storyService,
        dropService: widget.dropService,
        chatService: widget.chatService,
      ),
    );
  }

  void _openEntity(DiscoverArtistEntity entity) {
    _openPage(entity.name, ScalableEntityDetailScreen(entity: entity));
  }

  void _openKpopEntity(KpopEntity entity) {
    if (_isBetaReal) {
      _openKpopProfile(entity);
      return;
    }
    final group = _discoverGroupForKpopEntity(entity);
    if (group != null) {
      _openGroup(group);
      return;
    }
    final idolMatch = _discoverIdolForKpopEntity(entity);
    if (idolMatch != null) {
      final (idol, group) = idolMatch;
      _openPage(
        idol.name,
        IdolDetailScreen(
          group: group,
          idol: idol,
          user: widget.user,
          fancamService: widget.fancamService,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          chatService: widget.chatService,
        ),
      );
      return;
    }
    _openKpopProfile(entity);
  }

  void _openKpopProfile(KpopEntity entity) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => KpopEntityProfileScreen(
          entity: entity,
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
        ),
      ),
    );
  }

  DiscoverGroup? _discoverGroupForKpopEntity(KpopEntity entity) {
    final entityKeys = _kpopEntityLookupKeys(entity);
    for (final group in discoverGroups) {
      final groupKeys = {
        _compactKpopKey(group.id),
        _compactKpopKey(group.name),
        ...group.aliases.map(_compactKpopKey),
      }..remove('');
      if (entityKeys.any(groupKeys.contains)) return group;
    }
    return null;
  }

  (DiscoverIdol, DiscoverGroup)? _discoverIdolForKpopEntity(KpopEntity entity) {
    final entityKeys = _kpopEntityLookupKeys(entity);
    for (final group in discoverGroups) {
      for (final idol in group.idols) {
        final idolKeys = {
          _compactKpopKey(idol.id),
          _compactKpopKey(idol.name),
          _compactKpopKey(idol.realName),
          _compactKpopKey(idol.fullName),
          ...idol.aliases.map(_compactKpopKey),
        }..remove('');
        if (entityKeys.any(idolKeys.contains)) return (idol, group);
      }
    }
    return null;
  }

  Set<String> _kpopEntityLookupKeys(KpopEntity entity) {
    return {
      _compactKpopKey(entity.id),
      _compactKpopKey(entity.name),
      _compactKpopKey(entity.normalizedName),
      ...entity.aliases.map(_compactKpopKey),
    }..remove('');
  }

  String _compactKpopKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Future<void> _toggleKpopEntityFollow(KpopEntity entity) async {
    if (_entityFollowBusyIds.contains(entity.id)) return;
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      _showSnack('Iniciá sesión para seguir grupos y artistas.');
      return;
    }
    final wasFollowing = _followedEntityIds.contains(entity.id);
    final previousCount = _kpopEntityFollowerCounts[entity.id];
    final optimisticCount = previousCount == null
        ? null
        : wasFollowing
        ? (previousCount - 1).clamp(0, previousCount).toInt()
        : previousCount + 1;
    setState(() {
      _entityFollowBusyIds.add(entity.id);
      if (wasFollowing) {
        _followedEntityIds.remove(entity.id);
      } else {
        _followedEntityIds.add(entity.id);
      }
      if (optimisticCount != null) {
        _kpopEntityFollowerCounts[entity.id] = optimisticCount;
      }
    });
    try {
      final followService = KpopEntityFollowService(client);
      await followService.setFollowing(
        entityId: entity.id,
        userId: authUser.id,
        following: !wasFollowing,
      );
      LocalFollowService.revision.value++;
      int? refreshedCount;
      try {
        refreshedCount = await followService.restoreFollowerCount(entity.id);
      } catch (error) {
        debugPrint('DISCOVER_ENTITY_FOLLOWER_REFRESH_ERROR $error');
      }
      if (!mounted) return;
      setState(() {
        if (refreshedCount != null) {
          _kpopEntityFollowerCounts[entity.id] = refreshedCount;
        }
        _entityFollowBusyIds.remove(entity.id);
      });
    } catch (error) {
      debugPrint('DISCOVER_ENTITY_FOLLOW_TOGGLE_ERROR $error');
      if (!mounted) return;
      setState(() {
        if (wasFollowing) {
          _followedEntityIds.add(entity.id);
        } else {
          _followedEntityIds.remove(entity.id);
        }
        if (previousCount == null) {
          _kpopEntityFollowerCounts.remove(entity.id);
        } else {
          _kpopEntityFollowerCounts[entity.id] = previousCount;
        }
        _entityFollowBusyIds.remove(entity.id);
      });
      _showSnack(
        'No pudimos guardar el seguimiento. Revisá si la migración de Buscar está corrida.',
      );
    }
  }

  Future<void> _openNewsTopicEditor() async {
    if (_newsTopicsSaving) return;
    final entities = _kpopEntities
        .where(
          (entity) =>
              entity.id.trim().isNotEmpty && entity.name.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (entities.isEmpty) {
      _showSnack(
        'No pudimos cargar el catálogo. Probá de nuevo en unos segundos.',
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewsTopicEditorSheet(
        entities: entities,
        initialSelection: Set<String>.from(_followedEntityIds),
        onSave: _saveNewsTopicSelection,
      ),
    );
  }

  Future<void> _saveNewsTopicSelection(Set<String> selectedEntityIds) async {
    if (_newsTopicsSaving) {
      throw const _NewsTopicSaveException(
        'Ya estamos guardando tus temas. Esperá un momento.',
      );
    }
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const _NewsTopicSaveException(
        'Iniciá sesión para guardar tus temas.',
      );
    }
    final previous = Set<String>.from(_followedEntityIds);
    if (previous.length == selectedEntityIds.length &&
        previous.containsAll(selectedEntityIds)) {
      return;
    }
    final affectedEntityIds = <String>{...previous, ...selectedEntityIds};
    setState(() => _newsTopicsSaving = true);
    try {
      final followService = KpopEntityFollowService(client);
      await followService.replaceFollowingSelection(
        userId: authUser.id,
        currentEntityIds: previous,
        selectedEntityIds: selectedEntityIds,
      );
      final restored = await _restoreFollowedEntityIds(client);
      Map<String, int>? refreshedCounts;
      try {
        refreshedCounts = await followService.restoreFollowerCounts(
          affectedEntityIds,
        );
      } catch (error) {
        debugPrint('NEWS_TOPIC_COUNTS_REFRESH_ERROR $error');
      }
      if (!mounted) return;
      setState(() {
        _followedEntityIds
          ..clear()
          ..addAll(restored);
        if (refreshedCounts != null) {
          _kpopEntityFollowerCounts.addAll(refreshedCounts);
        }
        final selectedTopicStillExists = _kpopEntities.any(
          (entity) =>
              restored.contains(entity.id) && entity.name == _newsArtist,
        );
        if (_newsArtist != 'Todos' && !selectedTopicStillExists) {
          _newsArtist = 'Todos';
        }
        _newsTopicsSaving = false;
      });
      LocalFollowService.revision.value++;
      _showSnack('Tus temas de noticias quedaron actualizados.');
    } catch (error) {
      debugPrint('NEWS_TOPIC_SAVE_ERROR $error');
      if (mounted) setState(() => _newsTopicsSaving = false);
      throw const _NewsTopicSaveException(
        'No pudimos guardar tus temas. Revisá tu conexión y probá de nuevo.',
      );
    }
  }

  Future<void> _toggleCommunity(DiscoverCommunity community) async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      _showSnack('Iniciá sesión para unirte a comunidades.');
      return;
    }
    if (!_looksLikeUuid(community.id)) {
      _showSnack('Falta activar comunidades reales en Supabase.');
      return;
    }
    final wasJoined = _joinedCommunityIds.contains(community.id);
    setState(() {
      if (wasJoined) {
        _joinedCommunityIds.remove(community.id);
      } else {
        _joinedCommunityIds.add(community.id);
      }
    });
    try {
      if (wasJoined) {
        await client
            .from('community_members')
            .delete()
            .eq('community_id', community.id)
            .eq('user_id', authUser.id);
      } else {
        await client.from('community_members').upsert({
          'community_id': community.id,
          'user_id': authUser.id,
          'role': 'member',
        }, onConflict: 'community_id,user_id');
      }
      await _restoreRealDiscoverData();
      await _restoreRealStats();
    } catch (error) {
      debugPrint('DISCOVER_COMMUNITY_TOGGLE_ERROR $error');
      if (!mounted) return;
      setState(() {
        if (wasJoined) {
          _joinedCommunityIds.add(community.id);
        } else {
          _joinedCommunityIds.remove(community.id);
        }
      });
      _showSnack('No pudimos actualizar la comunidad. Probá de nuevo.');
    }
  }

  void _openSuggestionComposer() {
    if (_isBetaReal) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _KpopEntitySuggestionSheet(
          artistTagService: widget.artistTagService,
          onOpenExisting: (entity) {
            Navigator.of(context).pop();
            _openKpopEntity(entity);
          },
          onSubmit: (draft) async {
            await widget.artistTagService.submitDetailedEntitySuggestion(draft);
            if (!mounted) return;
            _showSnack('${draft.name} quedó pendiente de revisión.');
          },
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuggestionSheet(
        onSubmit: (entity) {
          setState(() => _communityEntitySuggestions.insert(0, entity));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('${entity.name} quedó pendiente de revisión'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
      ),
    );
  }

  Future<void> _openCommunityComposer() async {
    final created = await showModalBottomSheet<DiscoverCommunity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommunityComposerSheet(
        onCreate: (community) async {
          if (_isBetaReal) return _createRealCommunity(community);
          return community;
        },
      ),
    );
    if (!mounted || created == null) return;
    setState(() {
      if (_isBetaReal) {
        _realCommunities
          ..removeWhere((community) => community.id == created.id)
          ..insert(0, created);
        _joinedCommunityIds.add(created.id);
      } else {
        _createdCommunities.insert(0, created);
      }
      _section = DiscoverSection.communities;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _isBetaReal
                ? '${created.name} creada'
                : '${created.name} creada en modo demo',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    if (_isBetaReal) _openCommunity(created);
  }

  Future<DiscoverCommunity> _createRealCommunity(
    DiscoverCommunity community,
  ) async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw StateError('Iniciá sesión para crear una comunidad.');
    }
    final slug = _communitySlug(community.name);
    if (slug.isEmpty) {
      throw StateError('Elegí un nombre de comunidad válido.');
    }
    try {
      final existing = await client
          .from('communities')
          .select('id')
          .eq('slug', slug)
          .limit(1);
      if (existing.isNotEmpty) {
        throw StateError('Ya existe una comunidad con ese nombre.');
      }
      final inserted = await client
          .from('communities')
          .insert({
            'owner_id': authUser.id,
            'slug': slug,
            'name': community.name,
            'country': community.country,
            'region': community.province,
            'city': community.city,
            'fandom': community.fandom,
            'description': community.description,
            'privacy': 'public',
            'status': 'active',
          })
          .select(
            'id,name,country,region,city,fandom,description,privacy,status',
          )
          .single();
      final created = _communityFromRow(inserted, {
        inserted['id'] as String? ?? '': 1,
      });
      await client.from('community_members').upsert({
        'community_id': created.id,
        'user_id': authUser.id,
        'role': 'owner',
      }, onConflict: 'community_id,user_id');
      return created;
    } catch (error) {
      debugPrint('DISCOVER_COMMUNITY_CREATE_ERROR $error');
      final message = error.toString();
      if (message.contains('duplicate') || message.contains('23505')) {
        throw StateError('Ya existe una comunidad con ese nombre.');
      }
      if (message.contains('slug') || message.contains('communities')) {
        throw StateError('Falta actualizar Supabase para crear comunidades.');
      }
      rethrow;
    }
  }

  String _communitySlug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug;
  }

  void _showBetaSoon(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BetaSoonSheet(title: title, message: message),
    );
  }

  void _openCommunity(DiscoverCommunity community) {
    if (_isBetaReal) {
      _openPage(
        community.name,
        _BetaCommunityDetailView(
          community: community,
          initiallyJoined: _joinedCommunityIds.contains(community.id),
          followService: widget.followService,
          safetyService: widget.safetyService,
          onOpenProfile: _openProfile,
          onMembershipChanged: () async {
            await _restoreRealDiscoverData();
            await _restoreRealStats();
          },
        ),
      );
      return;
    }
    _openPage(community.name, CommunityDetailScreen(community: community));
  }

  void _openFanEventComposer() {
    if (_isBetaReal) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _FanEventComposerSheet(
          onSubmit: (event) async {
            await _createFanEvent(event);
            if (!mounted) return;
            await _restoreRealDiscoverData();
            await _restoreRealStats();
            _showSnack('Evento publicado en Eventos de comunidad.');
          },
        ),
      );
      return;
    }
  }

  Future<void> _createFanEvent(_FanEventDraft draft) async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) throw StateError('Sin sesión activa');
    await client.from('fan_events').insert({
      'author_id': authUser.id,
      'title': draft.title,
      'fandom': draft.fandom,
      'country': draft.country,
      'city': draft.city,
      'place': draft.place,
      'starts_at': draft.startsAt.toUtc().toIso8601String(),
      'description': draft.description,
      'organizer_contact': draft.organizerContact,
      'external_link': draft.externalLink,
      'category': draft.category,
      'status': 'published',
    });
  }

  Future<void> _toggleFanEventAttendance(_FanEvent event) async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      _showSnack('Iniciá sesión para marcar asistencia.');
      return;
    }
    final wasAttending = _attendingEventIds.contains(event.id);
    setState(() {
      if (wasAttending) {
        _attendingEventIds.remove(event.id);
      } else {
        _attendingEventIds.add(event.id);
      }
    });
    try {
      if (wasAttending) {
        await client
            .from('fan_event_attendees')
            .delete()
            .eq('event_id', event.id)
            .eq('user_id', authUser.id);
      } else {
        await client.from('fan_event_attendees').upsert({
          'event_id': event.id,
          'user_id': authUser.id,
          'status': 'interested',
        }, onConflict: 'event_id,user_id');
      }
    } catch (error) {
      debugPrint('DISCOVER_EVENT_ATTEND_ERROR $error');
      if (!mounted) return;
      setState(() {
        if (wasAttending) {
          _attendingEventIds.add(event.id);
        } else {
          _attendingEventIds.remove(event.id);
        }
      });
      _showSnack('No pudimos guardar tu asistencia. Probá de nuevo.');
    }
  }

  void _openEvent(DiscoverEvent event) {
    if (_isBetaReal) {
      _openFanEventComposer();
      return;
    }
    _openPage(event.title, EventDetailScreen(event: event));
  }

  void _openGuide(DiscoverGuide guide) {
    if (_isBetaReal) {
      _showBetaSoon(
        'K-pop 101',
        'Las preguntas y respuestas reales van a llegar en una próxima etapa del acceso anticipado.',
      );
      return;
    }
    _openPage(guide.title, GuideDetailScreen(guide: guide));
  }

  void _openKpopQuestion(_KpopQuestion question) {
    _openPage(question.title, _KpopQuestionDetailView(question: question));
  }

  void _openKpopQuestionComposer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _KpopQuestionComposerSheet(
        onSubmit: (title, detail) async {
          await _createKpopQuestion(title: title, detail: detail);
          if (!mounted) return;
          await _restoreRealDiscoverData();
          await _restoreRealStats();
          _showSnack('Tu pregunta ya aparece en K-pop 101.');
        },
      ),
    );
  }

  Future<void> _createKpopQuestion({
    required String title,
    required String detail,
  }) async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) throw StateError('Sin sesión activa');
    await client.from('kpop101_questions').insert({
      'author_id': authUser.id,
      'title': title,
      'detail': detail,
      'status': 'open',
    });
  }

  void _openStore(DiscoverStore store) {
    if (_isBetaReal) {
      _openShopSuggestionSheet();
      return;
    }
    _openPage(store.name, StoreDetailScreen(store: store));
  }

  void _openShopSuggestionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShopSuggestionSheet(
        onSubmit: (draft) async {
          await _createShopSuggestion(draft);
          if (!mounted) return;
          _showSnack('Tu sugerencia quedó pendiente de revisión.');
        },
      ),
    );
  }

  Future<void> _createShopSuggestion(_ShopSuggestionDraft draft) async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) throw StateError('Sin sesión activa');
    await client.from('shop_suggestions').insert({
      'suggested_by': authUser.id,
      'name': draft.name,
      'city': draft.city,
      'country': draft.country,
      'contact_url': draft.contact,
      'store_type': draft.type,
      'description': draft.description,
      'status': 'pending',
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _openProfile(CommunityProfile profile) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          profile: profile,
          currentUser: widget.user,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          chatService: widget.chatService,
          contentCategoryService: widget.contentCategoryService,
          userTagService: widget.userTagService,
          artistTagService: widget.artistTagService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
        ),
      ),
    );
  }

  List<DiscoverGroup> get _filteredGroups => _isBetaReal
      ? <DiscoverGroup>[]
      : discoverGroups
            .where(
              (group) => _matches(
                '${group.name} ${group.fandom} ${group.company} ${group.style} '
                '${group.aliases.join(' ')} ${group.country} ${group.region} '
                '${group.type.label} ${group.status.label} ${group.tags.join(' ')}',
              ),
            )
            .toList();

  List<DiscoverIdol> get _filteredIdols => _isBetaReal
      ? <DiscoverIdol>[]
      : discoverIdols
            .where(
              (idol) => _matches(
                '${idol.name} ${idol.realName} ${idol.role} ${idol.country} '
                '${idol.aliases.join(' ')} ${idol.tags.join(' ')}',
              ),
            )
            .toList();

  List<DiscoverArtistEntity> get _entityCatalog => [
    if (!_isBetaReal) ...discoverEmergingEntities,
    ..._communityEntitySuggestions,
  ];

  List<DiscoverArtistEntity> get _filteredEntities => _entityCatalog
      .where((entity) => _matches(entity.searchableText))
      .toList(growable: false);

  List<KpopEntity> get _filteredKpopEntities => _kpopEntities
      .where(
        (entity) => _matches(
          '${entity.searchableText} ${_editorialSearchText(entity)}',
        ),
      )
      .toList(growable: false);

  List<KpopEntity> get _filteredKpopGroups => _filteredKpopEntities
      .where((entity) => entity.type == KpopEntityType.group)
      .toList(growable: false);

  List<KpopEntity> get _filteredKpopIdols => _filteredKpopEntities
      .where((entity) => entity.type != KpopEntityType.group)
      .toList(growable: false);

  String _editorialSearchText(KpopEntity entity) {
    final group = _discoverGroupForKpopEntity(entity);
    if (group != null) {
      return '${group.company} ${group.fandom} ${group.country}';
    }
    final idol = _discoverIdolForKpopEntity(entity);
    if (idol != null) {
      return '${idol.$1.role} ${idol.$2.company} ${idol.$2.fandom} '
          '${idol.$1.country}';
    }
    return '';
  }

  List<DiscoverArtistEntity> get _visibleEntityCatalog {
    return _entityCatalog
        .where((entity) {
          final regionMatches =
              _entityRegion == 'Todos' ||
              entity.region.contains(_entityRegion) ||
              entity.country.contains(_entityRegion);
          final typeMatches = _entityType == null || entity.type == _entityType;
          return regionMatches && typeMatches;
        })
        .toList(growable: false);
  }

  List<DiscoverNews> get _filteredNews {
    final followedNames = _kpopEntities
        .where((entity) => _followedEntityIds.contains(entity.id))
        .expand((entity) => [entity.name, ...entity.aliases])
        .map((name) => name.toLowerCase())
        .toSet();
    final topicQuery = _newsTopicQuery.trim().toLowerCase();
    final source = _isBetaReal ? _realNews : discoverNews;
    final filtered = source
        .where((item) {
          final artistMatches =
              _newsArtist == 'Todos' ||
              item.entityLabel.toLowerCase() == _newsArtist.toLowerCase();
          final topicMatches =
              topicQuery.isEmpty ||
              item.searchableText.toLowerCase().contains(topicQuery);
          final followsItem = _newsMatchesFollowedEntity(item, followedNames);
          final categoryMatches = switch (_newsCategory) {
            'Siguiendo' => followsItem,
            'Oficiales' => item.editorialBadge == 'Oficial',
            _ => true,
          };
          return artistMatches &&
              topicMatches &&
              categoryMatches &&
              _matches(item.searchableText);
        })
        .toList(growable: false);
    filtered.sort((a, b) {
      if (_newsCategory == 'Para vos') {
        final aFollowed = _newsMatchesFollowedEntity(a, followedNames);
        final bFollowed = _newsMatchesFollowedEntity(b, followedNames);
        if (aFollowed != bFollowed) return aFollowed ? -1 : 1;
      }
      final aDate = a.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return filtered;
  }

  bool _newsMatchesFollowedEntity(
    DiscoverNews item,
    Set<String> followedNames,
  ) {
    if (item.relatedEntityIds.any(_followedEntityIds.contains)) return true;
    return [
      item.artist,
      ...item.relatedGroups,
      ...item.relatedArtists,
    ].any((name) => followedNames.contains(name.toLowerCase()));
  }

  List<DiscoverCommunity> get _allCommunities => [
    if (_isBetaReal)
      ..._realCommunities
    else ...[
      ..._createdCommunities,
      ...discoverCommunities,
    ],
  ];

  List<DiscoverCommunity> get _filteredCommunities => _allCommunities
      .where(
        (item) => _matches(
          '${item.name} ${item.region} ${item.country} ${item.province} ${item.city} ${item.fandom} ${item.description} ${item.privacy}',
        ),
      )
      .toList();

  List<DiscoverEvent> get _filteredEvents => _isBetaReal
      ? <DiscoverEvent>[]
      : discoverEvents
            .where(
              (item) => _matches(
                '${item.title} ${item.city} ${item.country} ${item.location} ${item.organizer} ${item.fandom} ${item.description}',
              ),
            )
            .toList();

  List<DiscoverGuide> get _filteredGuides => _isBetaReal
      ? <DiscoverGuide>[]
      : discoverGuides
            .where(
              (item) => _matches(
                '${item.title} ${item.category} ${item.summary} ${item.body}',
              ),
            )
            .toList();

  List<DiscoverStore> get _filteredStores => _isBetaReal
      ? <DiscoverStore>[]
      : discoverStores
            .where(
              (item) => _matches(
                '${item.name} ${item.city} ${item.country} ${item.category} ${item.description} ${item.products.join(' ')}',
              ),
            )
            .toList();

  List<CommunityProfile> get _filteredProfiles {
    final source = _profiles.isEmpty && !widget.followService.usesRealProfiles
        ? demoProfiles
        : _profiles;
    return source
        .where(
          (item) => _matches(
            '${item.name} ${item.username} ${item.city} ${item.country} ${item.fandom} ${item.favoriteGroup} ${item.bio}',
          ),
        )
        .toList(growable: false);
  }

  List<_FanEvent> get _filteredFanEvents => _fanEvents
      .where(
        (event) => _matches(
          '${event.title} ${event.fandom} ${event.city} ${event.country} '
          '${event.place} ${event.description} ${event.category}',
        ),
      )
      .toList(growable: false);

  List<_KpopQuestion> get _filteredKpopQuestions => _kpopQuestions
      .where((question) => _matches('${question.title} ${question.detail}'))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;
    final content = hasQuery
        ? <Widget>[
            _SearchResults(
              groups: _filteredGroups,
              idols: _filteredIdols,
              kpopEntities: _isBetaReal
                  ? _filteredKpopEntities
                  : const <KpopEntity>[],
              news: _filteredNews,
              entities: _filteredEntities,
              communities: _filteredCommunities,
              events: _filteredEvents,
              guides: _filteredGuides,
              stores: _filteredStores,
              profiles: _filteredProfiles,
              realMode: _isBetaReal,
              followerCounts: _kpopEntityFollowerCounts,
              followerCountsLoading: _entityFollowerCountsLoading,
              onGroup: _openGroup,
              onIdol: _openIdol,
              onKpopEntity: _openKpopEntity,
              onEntity: _openEntity,
              onNews: _openNews,
              onCommunity: _openCommunity,
              onEvent: _openEvent,
              onGuide: _openGuide,
              onStore: _openStore,
              onProfile: _openProfile,
              onAddEntity: _openSuggestionComposer,
            ),
          ]
        : _sectionContent();
    return Stack(
      children: [
        const _DiscoverAura(),
        ListView(
          key: const ValueKey('discover-scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          children: [
            _DiscoverSearchField(onChanged: _onQueryChanged),
            if (_query.trim().length >= 3 &&
                (_entitySuggestionsLoading ||
                    _entitySuggestions.isNotEmpty ||
                    _entitySuggestionsNoMatch))
              _EntitySuggestionsPanel(
                suggestions: _entitySuggestions,
                loading: _entitySuggestionsLoading,
                noMatch: _entitySuggestionsNoMatch,
                onTap: (entity) {
                  setState(() {
                    _entitySuggestions.clear();
                    _entitySuggestionsNoMatch = false;
                    _entitySuggestionsLoading = false;
                  });
                  _openKpopEntity(entity);
                },
              ),
            const SizedBox(height: 14),
            _DiscoverFilterBar(selected: _section, onSelected: _selectSection),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Column(
                key: ValueKey(
                  hasQuery
                      ? 'query-${_query.trim()}'
                      : 'section-${_section.name}',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _sectionContent() {
    switch (_section) {
      case DiscoverSection.all:
        return _overview();
      case DiscoverSection.groups:
        return _groupList();
      case DiscoverSection.idols:
        return _idolList();
      case DiscoverSection.news:
        return _newsList();
      case DiscoverSection.communities:
        return _communityList();
      case DiscoverSection.events:
        return _eventList();
      case DiscoverSection.rookie:
        return _guideList();
      case DiscoverSection.shop:
        return _storeList();
    }
  }

  List<Widget> _overview() {
    final highlightedEntities = <KpopEntity>[
      ..._kpopEntities.where(
        (entity) => _followedEntityIds.contains(entity.id),
      ),
      ..._kpopEntities.where(
        (entity) => !_followedEntityIds.contains(entity.id),
      ),
    ].take(6).toList(growable: false);

    return [
      if (_isBetaReal && highlightedEntities.isNotEmpty) ...[
        _KpopDiscoveryRail(
          entities: highlightedEntities,
          followedEntityIds: _followedEntityIds,
          followerCounts: _kpopEntityFollowerCounts,
          followerCountsLoading: _entityFollowerCountsLoading,
          busyEntityIds: _entityFollowBusyIds,
          onOpen: _openKpopEntity,
          onFollow: _toggleKpopEntityFollow,
          onSeeAll: () => _selectSection(DiscoverSection.groups),
          onSuggest: _openSuggestionComposer,
        ),
        const SizedBox(height: 24),
      ],
      const _SectionTitle(title: 'Para descubrir', trailing: 'Elegí tu mundo'),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.03,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _CategoryTile(
            key: const ValueKey('discover-open-groups'),
            icon: Icons.groups_2_outlined,
            title: 'Grupos e idols',
            subtitle: 'Explorá grupos y artistas',
            color: AppTheme.cyan,
            backgroundAsset: 'assets/brand/hally_discover_groups_stage_v2.jpg',
            mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
            onTap: () => _selectSection(DiscoverSection.groups),
          ),
          _CategoryTile(
            icon: Icons.newspaper_outlined,
            title: 'Noticias',
            subtitle: _isBetaReal ? 'Fuentes y novedades' : 'Actualidad K-pop',
            color: AppTheme.rose,
            backgroundAsset: 'assets/brand/hally_discover_news_globe_v2.jpg',
            mascotAsset: 'assets/brand/hally_mascot_news_reader.png',
            onTap: () => _selectSection(DiscoverSection.news),
          ),
          _CategoryTile(
            key: const ValueKey('discover-open-communities'),
            icon: Icons.forum_outlined,
            title: 'Comunidades',
            subtitle: _isBetaReal ? 'Comunidades base' : 'Por región',
            color: AppTheme.violet,
            backgroundAsset: 'assets/brand/hally_discover_communities_v2.jpg',
            mascotAsset: 'assets/brand/hally_mascot_community.png',
            onTap: () => _selectSection(DiscoverSection.communities),
          ),
          _CategoryTile(
            icon: Icons.event_outlined,
            title: 'Eventos',
            subtitle: _isBetaReal ? 'Propuestas reales' : 'Planes fandom',
            color: AppTheme.teal,
            backgroundAsset: 'assets/brand/hally_discover_events_v2.jpg',
            mascotAsset: 'assets/brand/hally_mascot_events_ticket.png',
            onTap: () => _selectSection(DiscoverSection.events),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const _SectionTitle(
        title: 'Más para explorar',
        trailing: 'Accesos rápidos',
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 112,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _ExploreShortcutTile(
              key: const ValueKey('search-open-kpop-101'),
              icon: Icons.school_outlined,
              title: 'K-pop 101',
              subtitle: _isBetaReal ? 'Muy pronto' : 'Guías',
              color: AppTheme.amber,
              backgroundAsset: 'assets/brand/hally_explore_kpop101_card_v1.png',
              onTap: () => _selectSection(DiscoverSection.rookie),
            ),
            const SizedBox(width: 10),
            _ExploreShortcutTile(
              key: const ValueKey('search-open-stores'),
              icon: Icons.storefront_outlined,
              title: 'Tiendas',
              subtitle: _isBetaReal ? 'Perfiles reales' : 'Explorar',
              color: AppTheme.indigo,
              backgroundAsset: 'assets/brand/hally_explore_stores_card_v1.png',
              onTap: () => _selectSection(DiscoverSection.shop),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _SectionTitle(
        title: 'HallyuHub hoy',
        trailing: _isBetaReal ? 'Datos reales' : 'Vista local',
      ),
      const SizedBox(height: 10),
      _DiscoverActivityStrip(realMode: _isBetaReal, stats: _realStats),
      if (_isBetaReal) ...[
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'Comunidades cerca tuyo',
          trailing: 'Ver todas',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 146,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _allCommunities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _allCommunities[index];
              return _CommunityPreviewCard(
                item: item,
                joined: _joinedCommunityIds.contains(item.id),
                onOpen: () => _openCommunity(item),
                onToggle: () => _toggleCommunity(item),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _DiscoverActionCard(
                title: 'Proponé un evento',
                subtitle: 'Activá a tu fandom.',
                actionLabel: 'Proponer',
                icon: Icons.confirmation_number_outlined,
                accent: AppTheme.teal,
                mascotAsset: 'assets/brand/hally_mascot_events_ticket.png',
                onTap: _openFanEventComposer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DiscoverActionCard(
                title: 'Sugerí una tienda',
                subtitle: 'Sumá un proyecto fan.',
                actionLabel: 'Sugerir',
                icon: Icons.shopping_bag_outlined,
                accent: AppTheme.indigo,
                mascotAsset: 'assets/brand/hally_mascot_shop_bag.png',
                onTap: _openShopSuggestionSheet,
              ),
            ),
          ],
        ),
      ] else ...[
        const SizedBox(height: 24),
        const _SectionTitle(title: 'Grupos en radar', trailing: 'Deslizá'),
        const SizedBox(height: 10),
        SizedBox(
          height: 174,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: discoverGroups.take(10).length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final group = discoverGroups[index];
              return _GroupRailCard(
                group: group,
                onTap: () => _openGroup(group),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('discover-suggest-entity'),
            onPressed: _openSuggestionComposer,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('+ Agregar grupo o artista'),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'Noticias actuales',
          trailing: 'Modo demo local',
        ),
        const SizedBox(height: 10),
        _EditorialNewsStack(
          items: discoverNews.take(3).toList(),
          onTap: _openNews,
        ),
        const SizedBox(height: 20),
        const _SectionTitle(
          title: 'Comunidades cerca',
          trailing: 'Latinoamérica',
        ),
        const SizedBox(height: 10),
        ..._allCommunities
            .take(3)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CommunityCard(
                  item: item,
                  onTap: () => _openCommunity(item),
                ),
              ),
            ),
      ],
    ];
  }

  List<Widget> _groupList() => [
    const HallyFeatureTip(
      featureId: 'artists_intro',
      title: 'Descubrí artistas con Hally 💜',
      message: 'Buscá grupos y artistas; etiquetalos en tus publicaciones.',
      mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
    ),
    _SectionTitle(
      title: 'Grupos y artistas',
      trailing: '',
    ),
    const SizedBox(height: 10),
    if (_isBetaReal) ...[
      if (_filteredKpopGroups.isEmpty)
        _EmptyPanel(
          title: 'Explorá grupos e idols',
          text:
              'Estamos preparando el catálogo base de grupos para el acceso anticipado. También podés sugerir artistas nuevos, rookies o proyectos locales.',
          actionLabel: 'Agregar grupo o artista',
          onAction: _openSuggestionComposer,
          mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
          icon: Icons.auto_awesome_rounded,
          accent: AppTheme.cyan,
        )
      else
        ..._filteredKpopGroups.map(
          (entity) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _KpopEntityCard(
              entity: entity,
              followed: _followedEntityIds.contains(entity.id),
              followerCount: _kpopEntityFollowerCounts[entity.id],
              followerCountLoading: _entityFollowerCountsLoading,
              followBusy: _entityFollowBusyIds.contains(entity.id),
              onOpen: () => _openKpopEntity(entity),
              onFollow: () => _toggleKpopEntityFollow(entity),
            ),
          ),
        ),
      const SizedBox(height: 10),
      _EmptyPanel(
        title: 'Contenido fan etiquetado',
        text:
            'El contenido de fans va a aparecer cuando alguien etiquete un grupo, idol o artista real.',
        actionLabel: 'Agregar grupo o artista',
        onAction: _openSuggestionComposer,
        mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
        icon: Icons.light_mode_outlined,
        accent: AppTheme.violet,
      ),
    ] else ...[
      ..._filteredGroups.map(
        (group) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GroupListCard(group: group, onTap: () => _openGroup(group)),
        ),
      ),
      const SizedBox(height: 10),
      _EntityFilterPanel(
        selectedRegion: _entityRegion,
        selectedType: _entityType,
        onRegion: (region) => setState(() => _entityRegion = region),
        onType: (type) => setState(() => _entityType = type),
        onSuggest: _openSuggestionComposer,
      ),
      const SizedBox(height: 16),
      _SectionTitle(
        title: 'Emergentes y comunidad',
        trailing: '${_visibleEntityCatalog.length} resultados',
      ),
      const SizedBox(height: 10),
      if (_visibleEntityCatalog.isEmpty)
        const _EmptyPanel(
          title: 'Sugerencias de la comunidad',
          text:
              'No hay proyectos con ese filtro todavía. Podés sugerir uno para dejarlo pendiente de revisión.',
          mascotAsset: 'assets/brand/hally_mascot_kpop101.png',
          icon: Icons.person_add_alt_1_rounded,
          accent: AppTheme.violet,
        )
      else
        ..._visibleEntityCatalog.map(
          (entity) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EntityCard(
              entity: entity,
              onTap: () => _openEntity(entity),
            ),
          ),
        ),
    ],
  ];

  List<Widget> _idolList() => [
    const HallyFeatureTip(
      featureId: 'artists_intro',
      title: 'Descubrí artistas con Hally 💜',
      message: 'Buscá grupos y artistas; etiquetalos en tus publicaciones.',
      mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
    ),
    _SectionTitle(
      title: 'Artistas y solistas',
      trailing: '',
    ),
    const SizedBox(height: 10),
    if (_isBetaReal)
      if (_filteredKpopIdols.isEmpty)
        _EmptyPanel(
          title: 'Idols y solistas',
          text:
              'Estamos preparando el catálogo base de idols y artistas. Podés sugerir perfiles para revisión.',
          actionLabel: 'Agregar grupo o artista',
          onAction: _openSuggestionComposer,
          mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
          icon: Icons.star_border_rounded,
          accent: AppTheme.rose,
        )
      else
        ..._filteredKpopIdols.map(
          (entity) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _KpopEntityCard(
              entity: entity,
              followed: _followedEntityIds.contains(entity.id),
              followerCount: _kpopEntityFollowerCounts[entity.id],
              followerCountLoading: _entityFollowerCountsLoading,
              followBusy: _entityFollowBusyIds.contains(entity.id),
              onOpen: () => _openKpopEntity(entity),
              onFollow: () => _toggleKpopEntityFollow(entity),
            ),
          ),
        )
    else
      ..._filteredIdols
          .take(60)
          .map(
            (idol) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IdolCard(idol: idol, onTap: () => _openIdol(idol)),
            ),
          ),
  ];

  List<Widget> _newsList() {
    final topicQuery = _newsTopicQuery.trim().toLowerCase();
    final followedNewsTopics = _kpopEntities
        .where((item) => _followedEntityIds.contains(item.id))
        .toList(growable: false);
    final newsTopics = _kpopEntities
        .where((item) => item.type == KpopEntityType.group)
        .where(
          (item) =>
              topicQuery.isEmpty ||
              item.name.toLowerCase().contains(topicQuery) ||
              item.aliases.any(
                (alias) => alias.toLowerCase().contains(topicQuery),
              ),
        )
        .take(topicQuery.isEmpty ? 0 : 12)
        .toList(growable: false);
    return [
      if (_isBetaReal) ...[
        const _NewsIntroPanel(
          title: 'Noticias K-pop',
          subtitle:
              'Novedades claras, fuentes visibles y enlaces directos para seguir el K-pop sin ruido.',
        ),
        const SizedBox(height: 12),
        _NewsTopicSearchField(
          value: _newsTopicQuery,
          onChanged: (value) => setState(() => _newsTopicQuery = value),
        ),
        const SizedBox(height: 9),
        Text(
          'Buscá noticias, grupos o artistas. Marcá tus favoritos para personalizar esta sección.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (topicQuery.isNotEmpty) ...[
          _NewsMiniHeading(
            title: 'Resultados para seguir',
            action: newsTopics.isEmpty ? null : '${newsTopics.length}',
          ),
          const SizedBox(height: 8),
          if (newsTopics.isEmpty)
            const _NewsEmptyStrip(
              text: 'No encontramos ese grupo. Probá con otro nombre.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entity in newsTopics)
                  _FollowTopicChip(
                    label: entity.name,
                    followed: _followedEntityIds.contains(entity.id),
                    followerCount: _kpopEntityFollowerCounts[entity.id],
                    followerCountLoading: _entityFollowerCountsLoading,
                    busy: _entityFollowBusyIds.contains(entity.id),
                    onTap: () {
                      setState(() => _newsArtist = entity.name);
                      _toggleKpopEntityFollow(entity);
                    },
                  ),
              ],
            ),
          const SizedBox(height: 16),
        ],
        _NewsMiniHeading(
          title: 'Tus temas seguidos',
          action: 'Editar',
          onAction: _openNewsTopicEditor,
        ),
        const SizedBox(height: 8),
        if (followedNewsTopics.isEmpty)
          const _NewsEmptyStrip(
            text: 'Todavía no marcaste grupos. Buscá uno arriba para seguirlo.',
          )
        else
          _NewsFollowedTopicRail(
            topics: followedNewsTopics,
            selected: _newsArtist,
            onSelected: (name) => setState(() => _newsArtist = name),
          ),
        const SizedBox(height: 12),
        _NewsFilterRail(
          selected: _newsCategory,
          onSelected: (value) {
            setState(() {
              _newsCategory = value;
              if (value == 'Para vos') _newsArtist = 'Todos';
            });
          },
        ),
        const SizedBox(height: 14),
        if (_newsLoading)
          const _NewsLoadingList()
        else if (_newsError != null)
          _EmptyPanel(
            title: 'No pudimos actualizar las noticias',
            text:
                'Revisá tu conexión y volvé a intentar. El resto de Buscar sigue disponible.',
            actionLabel: 'Reintentar',
            onAction: _restoreRealNews,
            mascotAsset: 'assets/brand/hally_mascot_news_reader.png',
            icon: Icons.refresh_rounded,
            accent: AppTheme.rose,
          )
        else if (_filteredNews.isEmpty)
          _EmptyPanel(
            title: 'Todavía no hay noticias para mostrar',
            text:
                'Cuando publiquemos novedades con fecha, fuente y enlace real, van a aparecer acá.',
            mascotAsset: 'assets/brand/hally_mascot_news_reader.png',
            icon: Icons.manage_search_rounded,
            accent: AppTheme.rose,
          )
        else
          for (var index = 0; index < _filteredNews.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NewsCard(
                item: _filteredNews[index],
                layout: _newsCardLayoutForIndex(index),
                onTap: () => _openNews(_filteredNews[index]),
              ),
            ),
      ] else ...[
        _ArtistFilterBar(
          artists: [
            'Todos',
            ...discoverNews.map((item) => item.artist).toSet(),
          ],
          selected: _newsArtist,
          onSelected: (artist) => setState(() => _newsArtist = artist),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < _filteredNews.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NewsCard(
              item: _filteredNews[index],
              layout: _newsCardLayoutForIndex(index),
              onTap: () => _openNews(_filteredNews[index]),
            ),
          ),
      ],
    ];
  }

  List<Widget> _communityList() {
    if (!_isBetaReal) {
      return [
        const HallyFeatureTip(
          featureId: 'communities_intro',
          title: 'Encontrá tu comunidad 💜',
          message: 'Unite a comunidades de tu ciudad, país o fandom.',
          mascotAsset: 'assets/brand/hally_mascot_community.png',
        ),
        const _SectionTitle(
          title: 'Comunidades latinas',
          trailing: 'Chat local',
        ),
        const SizedBox(height: 10),
        _CreateCommunityPanel(onTap: _openCommunityComposer),
        const SizedBox(height: 14),
        ..._filteredCommunities.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CommunityCard(
              item: item,
              onTap: () => _openCommunity(item),
            ),
          ),
        ),
      ];
    }

    final sections = splitCommunityMembership(
      communities: _realCommunities,
      joinedIds: _joinedCommunityIds,
      query: _query,
    );
    return [
      const HallyFeatureTip(
        featureId: 'communities_intro',
        title: 'Encontrá tu comunidad 💜',
        message: 'Unite a comunidades de tu ciudad, país o fandom.',
        mascotAsset: 'assets/brand/hally_mascot_community.png',
      ),
      const _SectionTitle(title: 'Comunidades', trailing: 'HallyuHub'),
      const SizedBox(height: 7),
      Text('Conectá con fans de tu ciudad, país o fandom.', style: _mutedStyle),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Mis comunidades', trailing: ''),
      const SizedBox(height: 11),
      if (sections.joined.isEmpty)
        const _EmptyPanel(
          key: ValueKey('communities-empty-joined'),
          title: 'Aún no te uniste a ninguna comunidad',
          text: 'Cuando te unas, tus comunidades van a aparecer primero acá.',
          icon: Icons.forum_outlined,
          accent: AppTheme.violet,
        )
      else
        ...sections.joined.map(
          (item) => Padding(
            key: ValueKey('joined-community-${item.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _BetaCommunityCard(
              item: item,
              joined: true,
              onOpen: () => _openCommunity(item),
              onToggle: () => _openCommunity(item),
            ),
          ),
        ),
      const SizedBox(height: 20),
      Container(
        key: _exploreCommunitiesKey,
        child: const _SectionTitle(title: 'Explorar comunidades', trailing: ''),
      ),
      const SizedBox(height: 5),
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          'Unite a más comunidades o creá la tuya.',
          style: _mutedStyle,
        ),
      ),
      const SizedBox(height: 12),
      _CommunityActionTile(
        icon: Icons.search_rounded,
        title: 'Descubrir comunidades',
        subtitle: 'Buscá por ciudad, país o fandom.',
        accent: AppTheme.cyan,
        onTap: _scrollToExploreCommunities,
      ),
      const SizedBox(height: 9),
      _CommunityActionTile(
        icon: Icons.add_rounded,
        title: 'Crear comunidad',
        subtitle: 'Creá un espacio por ciudad, fandom o proyecto fan.',
        accent: AppTheme.violet,
        onTap: _openCommunityComposer,
      ),
      if (sections.available.isNotEmpty) ...[
        const SizedBox(height: 14),
        ...List.generate(sections.available.length, (index) {
          final item = sections.available[index];
          return Padding(
            key: index == 0
                ? _discoverCommunitiesKey
                : ValueKey('available-community-${item.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _BetaCommunityCard(
              item: item,
              joined: false,
              onOpen: () => _openCommunity(item),
              onToggle: () => _toggleCommunity(item),
            ),
          );
        }),
      ] else if (_realCommunities.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: _EmptyPanel(
            key: ValueKey('communities-empty-explore'),
            text: 'Todavía no hay comunidades disponibles para explorar.',
            icon: Icons.travel_explore_rounded,
            accent: AppTheme.cyan,
          ),
        ),
    ];
  }

  void _scrollToExploreCommunities() {
    final targetContext =
        _discoverCommunitiesKey.currentContext ??
        _exploreCommunitiesKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  List<Widget> _eventList() => [
    _SectionTitle(
      title: 'Eventos de comunidad',
      trailing: _isBetaReal ? 'Acceso anticipado' : 'Agenda',
    ),
    const SizedBox(height: 10),
    if (_isBetaReal) ...[
      _EmptyPanel(
        title: 'Eventos para fans',
        text: _filteredFanEvents.isEmpty
            ? 'Todavía no hay eventos publicados por fans. Proponé un encuentro, cupsleeve o actividad para tu ciudad.'
            : '¿Tenés un plan fandom para compartir? Publicalo como propuesta real durante el acceso anticipado.',
        actionLabel: 'Proponer evento',
        onAction: _openFanEventComposer,
        mascotAsset: 'assets/brand/hally_mascot_events_ticket.png',
        icon: Icons.event_available_outlined,
        accent: AppTheme.teal,
      ),
      const SizedBox(height: 10),
      ..._filteredFanEvents.map(
        (event) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FanEventCard(
            event: event,
            attending: _attendingEventIds.contains(event.id),
            onAttend: () => _toggleFanEventAttendance(event),
          ),
        ),
      ),
    ] else
      ..._filteredEvents.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EventCard(item: item, onTap: () => _openEvent(item)),
        ),
      ),
  ];

  List<Widget> _guideList() => [
    _SectionTitle(
      title: 'K-pop 101',
      trailing: _isBetaReal ? _realStats.kpopQuestionsLabel : 'Guías',
    ),
    const SizedBox(height: 10),
    if (_isBetaReal) ...[
      ..._kpopGuideInfos.map(
        (guide) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _KpopGuideInfoCard(guide: guide),
        ),
      ),
      const SizedBox(height: 10),
      _SectionTitle(
        title: 'Preguntas de fans',
        trailing: _realStats.kpopQuestionsLabel,
      ),
      const SizedBox(height: 10),
      _EmptyPanel(
        title: 'Preguntale a Hally',
        text: _filteredKpopQuestions.isEmpty
            ? 'Todavía no hay preguntas. Sé la primera persona en preguntar y ayudar a otros fans.'
            : 'Compartí dudas reales de fandom y ayudá a mejorar el acceso anticipado.',
        actionLabel: 'Hacer pregunta',
        onAction: _openKpopQuestionComposer,
        mascotAsset: 'assets/brand/hally_mascot_kpop101.png',
        icon: Icons.psychology_alt_outlined,
        accent: AppTheme.amber,
      ),
      const SizedBox(height: 10),
      ..._filteredKpopQuestions.map(
        (question) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _KpopQuestionCard(
            question: question,
            onTap: () => _openKpopQuestion(question),
          ),
        ),
      ),
    ] else
      ..._filteredGuides.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GuideCard(item: item, onTap: () => _openGuide(item)),
        ),
      ),
  ];

  List<Widget> _storeList() => [
    _SectionTitle(
      title: 'Tiendas K-pop',
      trailing: _isBetaReal ? _realStats.verifiedStoresLabel : 'Demo seguro',
    ),
    const SizedBox(height: 10),
    if (_isBetaReal)
      _EmptyPanel(
        title: 'Shop fan seguro',
        text:
            'Todavía no hay tiendas verificadas en HallyuHub. Si conocés una tienda confiable, podés sugerirla.',
        actionLabel: 'Sugerir tienda',
        onAction: _openShopSuggestionSheet,
        mascotAsset: 'assets/brand/hally_mascot_shop_bag.png',
        icon: Icons.storefront_outlined,
        accent: AppTheme.indigo,
      )
    else
      ..._filteredStores.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _StoreCard(item: item, onTap: () => _openStore(item)),
        ),
      ),
  ];
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.groups,
    required this.idols,
    required this.kpopEntities,
    required this.news,
    required this.entities,
    required this.communities,
    required this.events,
    required this.guides,
    required this.stores,
    required this.profiles,
    required this.realMode,
    required this.followerCounts,
    required this.followerCountsLoading,
    required this.onGroup,
    required this.onIdol,
    required this.onKpopEntity,
    required this.onEntity,
    required this.onNews,
    required this.onCommunity,
    required this.onEvent,
    required this.onGuide,
    required this.onStore,
    required this.onProfile,
    required this.onAddEntity,
  });

  final List<DiscoverGroup> groups;
  final List<DiscoverIdol> idols;
  final List<KpopEntity> kpopEntities;
  final List<DiscoverNews> news;
  final List<DiscoverArtistEntity> entities;
  final List<DiscoverCommunity> communities;
  final List<DiscoverEvent> events;
  final List<DiscoverGuide> guides;
  final List<DiscoverStore> stores;
  final List<CommunityProfile> profiles;
  final bool realMode;
  final Map<String, int> followerCounts;
  final bool followerCountsLoading;
  final ValueChanged<DiscoverGroup> onGroup;
  final ValueChanged<DiscoverIdol> onIdol;
  final ValueChanged<KpopEntity> onKpopEntity;
  final ValueChanged<DiscoverArtistEntity> onEntity;
  final ValueChanged<DiscoverNews> onNews;
  final ValueChanged<DiscoverCommunity> onCommunity;
  final ValueChanged<DiscoverEvent> onEvent;
  final ValueChanged<DiscoverGuide> onGuide;
  final ValueChanged<DiscoverStore> onStore;
  final ValueChanged<CommunityProfile> onProfile;
  final VoidCallback onAddEntity;

  @override
  Widget build(BuildContext context) {
    final hasResults =
        groups.isNotEmpty ||
        idols.isNotEmpty ||
        kpopEntities.isNotEmpty ||
        news.isNotEmpty ||
        entities.isNotEmpty ||
        communities.isNotEmpty ||
        events.isNotEmpty ||
        guides.isNotEmpty ||
        stores.isNotEmpty ||
        profiles.isNotEmpty;
    if (!hasResults) {
      return _EmptyPanel(
        title: 'No encontramos resultados',
        text:
            'No encontramos ese grupo o artista. También podés buscar personas, comunidades o una palabra clave.',
        actionLabel: 'Agregar a HallyuHub',
        onAction: onAddEntity,
        mascotAsset: 'assets/brand/hally_mascot_kpop101.png',
        icon: Icons.search_rounded,
        accent: AppTheme.cyan,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Resultados',
          trailing: realMode ? 'Acceso anticipado' : 'Demo local',
        ),
        const SizedBox(height: 12),
        if (groups.isNotEmpty) ...[
          _ResultHeading('Grupos', groups.length),
          ...groups
              .take(4)
              .map(
                (item) => _ResultTile(
                  icon: Icons.groups_2_outlined,
                  title: item.name,
                  subtitle: '${item.fandom} · ${item.company}',
                  onTap: () => onGroup(item),
                ),
              ),
        ],
        if (idols.isNotEmpty) ...[
          _ResultHeading('Idols', idols.length),
          ...idols
              .take(5)
              .map(
                (item) => _ResultTile(
                  icon: Icons.person_search_outlined,
                  title: item.name,
                  subtitle: item.role,
                  onTap: () => onIdol(item),
                ),
              ),
        ],
        if (kpopEntities.isNotEmpty) ...[
          _ResultHeading('Catálogo K-pop', kpopEntities.length),
          ...kpopEntities
              .take(8)
              .map(
                (item) => _ResultTile(
                  icon: item.type == KpopEntityType.group
                      ? Icons.groups_2_outlined
                      : Icons.person_search_outlined,
                  title: item.name,
                  subtitle: [
                    item.typeLabel,
                    if (item.bio.trim().isNotEmpty) item.bio.trim(),
                    if (!followerCountsLoading)
                      followerCounts[item.id] == null
                          ? '— seguidores'
                          : formatKpopFollowerCount(followerCounts[item.id]!),
                  ].join(' · '),
                  badge: item.verified ? 'Verificado' : '',
                  color: AppTheme.cyan,
                  onTap: () => onKpopEntity(item),
                ),
              ),
        ],
        if (entities.isNotEmpty) ...[
          _ResultHeading('Artistas y proyectos', entities.length),
          ...entities
              .take(5)
              .map(
                (item) => _ResultTile(
                  icon: _entityIcon(item.type),
                  title: item.name,
                  subtitle:
                      '${item.type.label} · ${item.status.label} · ${item.region}',
                  badge: item.status.label,
                  color: _entityColor(item.status),
                  onTap: () => onEntity(item),
                ),
              ),
        ],
        if (news.isNotEmpty) ...[
          _ResultHeading('Noticias', news.length),
          ...news
              .take(3)
              .map(
                (item) => _ResultTile(
                  icon: Icons.newspaper_outlined,
                  title: item.displayTitle,
                  subtitle: '${item.displaySource} · ${item.publishedLabel}',
                  onTap: () => onNews(item),
                ),
              ),
        ],
        if (communities.isNotEmpty) ...[
          _ResultHeading('Comunidades', communities.length),
          ...communities
              .take(3)
              .map(
                (item) => _ResultTile(
                  icon: Icons.forum_outlined,
                  title: item.name,
                  subtitle: '${item.region} · ${item.members}',
                  onTap: () => onCommunity(item),
                ),
              ),
        ],
        if (events.isNotEmpty) ...[
          _ResultHeading('Eventos', events.length),
          ...events
              .take(3)
              .map(
                (item) => _ResultTile(
                  icon: Icons.event_outlined,
                  title: item.title,
                  subtitle: '${item.city} · ${item.date}',
                  onTap: () => onEvent(item),
                ),
              ),
        ],
        if (guides.isNotEmpty) ...[
          _ResultHeading('K-pop 101', guides.length),
          ...guides
              .take(3)
              .map(
                (item) => _ResultTile(
                  icon: Icons.school_outlined,
                  title: item.title,
                  subtitle: item.summary,
                  onTap: () => onGuide(item),
                ),
              ),
        ],
        if (stores.isNotEmpty) ...[
          _ResultHeading('Tiendas', stores.length),
          ...stores
              .take(3)
              .map(
                (item) => _ResultTile(
                  icon: Icons.storefront_outlined,
                  title: item.name,
                  subtitle: '${item.city} · ★ ${item.rating}',
                  onTap: () => onStore(item),
                ),
              ),
        ],
        if (profiles.isNotEmpty) ...[
          _ResultHeading('Usuarios', profiles.length),
          ...profiles
              .take(4)
              .map(
                (item) => _ResultTile(
                  icon: Icons.alternate_email,
                  title: item.name,
                  subtitle: '${item.username} · ${item.city}',
                  onTap: () => onProfile(item),
                ),
              ),
        ],
      ],
    );
  }
}

class _DiscoverAura extends StatelessWidget {
  const _DiscoverAura();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF020308),
                const Color(0xFF050611),
                AppTheme.violet.withValues(alpha: 0.035),
                const Color(0xFF020308),
              ],
              stops: const [0, 0.36, 0.72, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverFilterBar extends StatelessWidget {
  const _DiscoverFilterBar({required this.selected, required this.onSelected});

  final DiscoverSection selected;
  final ValueChanged<DiscoverSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DiscoverSection.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = DiscoverSection.values[index];
          return _DiscoverChip(
            key: ValueKey('discover-filter-${section.name}'),
            label: section.label,
            selected: selected == section,
            onTap: () => onSelected(section),
          );
        },
      ),
    );
  }
}

class _ArtistFilterBar extends StatelessWidget {
  const _ArtistFilterBar({
    required this.artists,
    required this.selected,
    required this.onSelected,
  });

  final List<String> artists;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final artist = artists[index];
          return _DiscoverChip(
            label: artist,
            selected: selected == artist,
            compact: true,
            onTap: () => onSelected(artist),
          );
        },
      ),
    );
  }
}

class _DiscoverChip extends StatelessWidget {
  const _DiscoverChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: [AppTheme.rose, AppTheme.violet])
            : null,
        color: selected ? null : const Color(0xFF060710),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.13),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.rose.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 15,
              vertical: compact ? 8 : 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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

class _DiscoverSearchField extends StatelessWidget {
  const _DiscoverSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF070810),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(-3, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const Icon(Icons.search_rounded, color: Colors.white, size: 27),
          const SizedBox(width: 13),
          Expanded(
            child: TextField(
              key: const ValueKey('search-input'),
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: AppTheme.cyan,
              decoration: InputDecoration(
                hintText: 'Buscar grupos, idols y noticias',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _EntitySuggestionsPanel extends StatelessWidget {
  const _EntitySuggestionsPanel({
    required this.suggestions,
    required this.loading,
    required this.noMatch,
    required this.onTap,
  });

  final List<KpopEntity> suggestions;
  final bool loading;
  final bool noMatch;
  final ValueChanged<KpopEntity> onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.violet.withValues(alpha: .42);
    return Container(
      margin: const EdgeInsets.only(top: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent),
      ),
      child: loading
          ? Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buscando grupos y artistas...',
                      style: _mutedStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : noMatch
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'No encontramos grupos o artistas con ese nombre.',
                style: _mutedStyle,
              ),
            )
          : Column(
              children: suggestions
                  .map(
                    (entity) => InkWell(
                      key: ValueKey('entity-suggestion-${entity.id}'),
                      onTap: () => onTap(entity),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            _KpopEntityAvatar(
                              entity: entity,
                              accent: _kpopIdentityAccent(entity.name),
                              size: 42,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entity.name, style: _compactTitleStyle),
                                  Text(entity.typeLabel, style: _eyebrowStyle),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.cyan,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _DiscoverRealStats {
  const _DiscoverRealStats({
    this.betaFans,
    this.eventCount,
    this.dropsToday,
    this.communityMembers,
    this.verifiedStores,
    this.kpopQuestions,
  });

  final int? betaFans;
  final int? eventCount;
  final int? dropsToday;
  final int? communityMembers;
  final int? verifiedStores;
  final int? kpopQuestions;

  _DiscoverRealStats copyWith({
    int? betaFans,
    int? eventCount,
    int? dropsToday,
    int? communityMembers,
    int? verifiedStores,
    int? kpopQuestions,
  }) {
    return _DiscoverRealStats(
      betaFans: betaFans ?? this.betaFans,
      eventCount: eventCount ?? this.eventCount,
      dropsToday: dropsToday ?? this.dropsToday,
      communityMembers: communityMembers ?? this.communityMembers,
      verifiedStores: verifiedStores ?? this.verifiedStores,
      kpopQuestions: kpopQuestions ?? this.kpopQuestions,
    );
  }

  String value(int? count, {String missingValue = '—'}) {
    if (count == null) return missingValue;
    return '$count';
  }

  String get verifiedStoresLabel {
    if (verifiedStores == null) return 'Sin tiendas';
    if (verifiedStores == 0) return 'Sin tiendas';
    return '$verifiedStores verificadas';
  }

  String get kpopQuestionsLabel {
    if (kpopQuestions == null) return 'Próximamente';
    if (kpopQuestions == 0) return 'Sin preguntas';
    return '$kpopQuestions preguntas';
  }
}

class _KpopDiscoveryRail extends StatelessWidget {
  const _KpopDiscoveryRail({
    required this.entities,
    required this.followedEntityIds,
    required this.followerCounts,
    required this.followerCountsLoading,
    required this.busyEntityIds,
    required this.onOpen,
    required this.onFollow,
    required this.onSeeAll,
    required this.onSuggest,
  });

  final List<KpopEntity> entities;
  final Set<String> followedEntityIds;
  final Map<String, int> followerCounts;
  final bool followerCountsLoading;
  final Set<String> busyEntityIds;
  final ValueChanged<KpopEntity> onOpen;
  final ValueChanged<KpopEntity> onFollow;
  final VoidCallback onSeeAll;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    final hasFollowed = entities.any(
      (entity) => followedEntityIds.contains(entity.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasFollowed ? 'Tus artistas' : 'Artistas para descubrir',
                style: _sectionTitleStyle,
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('Ver todos')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entity = entities[index];
              return _DiscoverEntityOrb(
                entity: entity,
                followed: followedEntityIds.contains(entity.id),
                followerCount: followerCounts[entity.id],
                followerCountLoading: followerCountsLoading,
                followBusy: busyEntityIds.contains(entity.id),
                onOpen: () => onOpen(entity),
                onFollow: () => onFollow(entity),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('discover-suggest-entity'),
            onPressed: onSuggest,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('+ Agregar grupo o artista'),
          ),
        ),
      ],
    );
  }
}

class _DiscoverEntityOrb extends StatelessWidget {
  const _DiscoverEntityOrb({
    required this.entity,
    required this.followed,
    required this.followerCount,
    required this.followerCountLoading,
    required this.followBusy,
    required this.onOpen,
    required this.onFollow,
  });

  final KpopEntity entity;
  final bool followed;
  final int? followerCount;
  final bool followerCountLoading;
  final bool followBusy;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final accent = _kpopIdentityAccent(entity.name);
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: _PressableScale(
              onTap: onOpen,
              borderRadius: 999,
              child: _KpopEntityAvatar(
                entity: entity,
                accent: accent,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            entity.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          if (followerCountLoading)
            Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
              ),
            )
          else
            Text(
              followerCount == null
                  ? '—'
                  : formatKpopFollowerCount(followerCount!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9496A4),
                fontSize: 8.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 5),
          Tooltip(
            message: followed ? 'Dejar de seguir' : 'Seguir',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('discover-follow-${entity.id}'),
                onTap: followBusy ? null : onFollow,
                borderRadius: BorderRadius.circular(99),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  height: 23,
                  decoration: BoxDecoration(
                    color: followed
                        ? AppTheme.cyan.withValues(alpha: .08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: followed
                          ? AppTheme.cyan.withValues(alpha: .65)
                          : Colors.white.withValues(alpha: .24),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: followBusy
                      ? const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              followed
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 11,
                              color: followed ? AppTheme.cyan : Colors.white70,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              followed ? 'Siguiendo' : 'Seguir',
                              style: TextStyle(
                                color: followed
                                    ? AppTheme.cyan
                                    : Colors.white70,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreShortcutTile extends StatelessWidget {
  const _ExploreShortcutTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.backgroundAsset,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String backgroundAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: _PressableScale(
        onTap: onTap,
        borderRadius: 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                backgroundAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: .34)),
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [.18, .56, 1],
                    colors: [
                      Colors.black.withValues(alpha: .02),
                      AppTheme.night.withValues(alpha: .2),
                      AppTheme.night.withValues(alpha: .9),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.night.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: color.withValues(alpha: .46)),
                      ),
                      child: Icon(icon, color: color, size: 21),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: _compactTitleStyle.copyWith(
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _miniMutedStyle.copyWith(
                        color: Colors.white70,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 6),
                        ],
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

class _CommunityPreviewCard extends StatelessWidget {
  const _CommunityPreviewCard({
    required this.item,
    required this.joined,
    required this.onOpen,
    required this.onToggle,
  });

  final DiscoverCommunity item;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visual = _CommunityVisualTheme.forCommunity(item);
    final membersLabel = _communityMembersLabel(item.members);

    return SizedBox(
      width: 278,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CommunityPlaceBackdrop(visual: visual),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommunityLocationBadge(
                        label: item.region,
                        visual: visual,
                        compact: true,
                      ),
                      const Spacer(),
                      Text(
                        item.name,
                        style: _compactTitleStyle.copyWith(
                          fontSize: 17,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.fandom} · $membersLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _miniMutedStyle.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              onPressed: onToggle,
                              style: _communityJoinButtonStyle(visual),
                              child: Text(joined ? 'Salir' : 'Unirme'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverActionCard extends StatelessWidget {
  const _DiscoverActionCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.accent,
    required this.mascotAsset,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Color accent;
  final String mascotAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        height: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: .2),
              AppTheme.nightSoft.withValues(alpha: .97),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: .2)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -10,
              child: Opacity(
                opacity: .72,
                child: Image.asset(
                  mascotAsset,
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: accent, size: 22),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _compactTitleStyle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _miniMutedStyle,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 15,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverActivityStrip extends StatelessWidget {
  const _DiscoverActivityStrip({required this.realMode, required this.stats});

  final bool realMode;
  final _DiscoverRealStats stats;

  @override
  Widget build(BuildContext context) {
    final items = realMode
        ? [
            _DiscoverActivityItem(
              icon: Icons.people_alt_outlined,
              value: stats.value(stats.betaFans),
              label: 'fans con acceso',
              color: AppTheme.cyan,
            ),
            _DiscoverActivityItem(
              icon: Icons.event_available_outlined,
              value: stats.value(stats.eventCount),
              label: 'eventos',
              color: AppTheme.teal,
            ),
            _DiscoverActivityItem(
              icon: Icons.bolt_outlined,
              value: stats.value(stats.dropsToday),
              label: 'drops hoy',
              color: AppTheme.amber,
            ),
            _DiscoverActivityItem(
              icon: Icons.forum_outlined,
              value: stats.value(stats.communityMembers, missingValue: '0'),
              label: 'miembros',
              color: AppTheme.violet,
            ),
            _DiscoverActivityItem(
              icon: Icons.storefront_outlined,
              value: stats.value(stats.verifiedStores),
              label: 'tiendas',
              color: AppTheme.indigo,
            ),
            _DiscoverActivityItem(
              icon: Icons.school_outlined,
              value: stats.value(stats.kpopQuestions),
              label: 'preguntas',
              color: AppTheme.rose,
            ),
          ]
        : [
            _DiscoverActivityItem(
              icon: Icons.event_available_outlined,
              value: homeMetrics[0].value,
              label: 'eventos activos',
              color: homeMetrics[0].color,
            ),
            _DiscoverActivityItem(
              icon: Icons.people_alt_outlined,
              value: homeMetrics[1].value,
              label: 'conectados',
              color: homeMetrics[1].color,
            ),
            _DiscoverActivityItem(
              icon: Icons.bolt_outlined,
              value: homeMetrics[2].value,
              label: 'drops del día',
              color: homeMetrics[2].color,
            ),
            const _DiscoverActivityItem(
              icon: Icons.local_fire_department_outlined,
              value: '18',
              label: 'tendencias',
              color: AppTheme.rose,
            ),
          ];
    return SizedBox(
      key: const ValueKey('discover-activity-strip'),
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _DiscoverActivityItem extends StatelessWidget {
  const _DiscoverActivityItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: _statValueStyle),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    height: 1.1,
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

class _KpopEntityCard extends StatelessWidget {
  const _KpopEntityCard({
    required this.entity,
    required this.followed,
    required this.followerCount,
    required this.followerCountLoading,
    required this.followBusy,
    required this.onOpen,
    required this.onFollow,
  });

  final KpopEntity entity;
  final bool followed;
  final int? followerCount;
  final bool followerCountLoading;
  final bool followBusy;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final accent = _kpopIdentityAccent(entity.name);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .1),
            AppTheme.nightSoft.withValues(alpha: .94),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _KpopEntityAvatar(entity: entity, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entity.typeLabel, style: _eyebrowStyle),
                    const SizedBox(height: 3),
                    Text(
                      entity.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (followerCountLoading)
                      Container(
                        width: 82,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      )
                    else
                      Text(
                        followerCount == null
                            ? '— seguidores'
                            : formatKpopFollowerCount(followerCount!),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      entity.bio.isEmpty
                          ? 'Perfil base preparado para contenido etiquetado real.'
                          : entity.bio,
                      style: _mutedStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: followBusy ? null : onFollow,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: followed
                      ? AppTheme.cyan.withValues(alpha: .5)
                      : accent.withValues(alpha: .4),
                ),
                foregroundColor: followed ? AppTheme.cyan : Colors.white,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                followBusy
                    ? '...'
                    : followed
                    ? 'Siguiendo'
                    : 'Seguir',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpopEntityAvatar extends StatelessWidget {
  const _KpopEntityAvatar({
    required this.entity,
    required this.accent,
    this.size = 62,
  });

  final KpopEntity entity;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF020208),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: .86), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .34),
            blurRadius: 13,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: .12),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipOval(child: _visual()),
    );
  }

  Widget _visual() {
    final imageUrl = entity.imageUrl.trim();
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    final imageAsset = entity.imageAsset.trim();
    if (imageAsset.isNotEmpty && !imageAsset.startsWith('assets/demo-')) {
      return Image.asset(
        imageAsset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return _KpopIdentityArtwork(entity: entity, accent: accent);
  }
}

class _KpopIdentityArtwork extends StatelessWidget {
  const _KpopIdentityArtwork({required this.entity, required this.accent});

  final KpopEntity entity;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.18, -.24),
          radius: 1.2,
          colors: [
            accent.withValues(alpha: .18),
            AppTheme.violet.withValues(alpha: .08),
            const Color(0xFF020208),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _KpopIdentityArtworkPainter(
              accent: accent,
              seed: entity.name.codeUnits.fold<int>(
                0,
                (sum, code) => sum + code,
              ),
            ),
          ),
          Center(
            child: _KpopIdentityEmblem(
              name: entity.name,
              type: entity.type,
              accent: accent,
            ),
          ),
        ],
      ),
    );
  }
}

enum _KpopEmblemKind { gates, orbit, prism, monogram }

class _KpopIdentityEmblem extends StatelessWidget {
  const _KpopIdentityEmblem({
    required this.name,
    required this.type,
    required this.accent,
  });

  final String name;
  final KpopEntityType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final kind = _kpopEmblemKind(name);
    if (kind != _KpopEmblemKind.monogram) {
      return SizedBox.square(
        dimension: 39,
        child: CustomPaint(
          painter: _KpopEmblemPainter(kind: kind, accent: accent),
        ),
      );
    }

    final wordmark = _kpopIdentityWordmark(name);
    final isLong = wordmark.length > 5;
    return Padding(
      padding: const EdgeInsets.all(9),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.cyan, AppTheme.violet, AppTheme.rose],
          ).createShader(bounds),
          child: Text(
            wordmark,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLong ? 16 : 25,
              height: .86,
              letterSpacing: isLong ? .2 : 1.1,
              fontWeight: type == KpopEntityType.group
                  ? FontWeight.w800
                  : FontWeight.w500,
              shadows: const [Shadow(color: AppTheme.violet, blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpopEmblemPainter extends CustomPainter {
  const _KpopEmblemPainter({required this.kind, required this.accent});

  final _KpopEmblemKind kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.cyan, accent, AppTheme.rose],
    ).createShader(bounds);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: .2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = shader;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = shader;

    switch (kind) {
      case _KpopEmblemKind.gates:
        final left = Path()
          ..moveTo(size.width * .13, size.height * .18)
          ..lineTo(size.width * .44, size.height * .34)
          ..lineTo(size.width * .44, size.height * .78)
          ..lineTo(size.width * .13, size.height * .62)
          ..close();
        final right = Path()
          ..moveTo(size.width * .87, size.height * .18)
          ..lineTo(size.width * .56, size.height * .34)
          ..lineTo(size.width * .56, size.height * .78)
          ..lineTo(size.width * .87, size.height * .62)
          ..close();
        canvas.drawPath(left, fill);
        canvas.drawPath(right, fill);
        break;
      case _KpopEmblemKind.orbit:
        final orbit = Path()
          ..moveTo(size.width * .08, size.height * .54)
          ..cubicTo(
            size.width * .22,
            size.height * .08,
            size.width * .45,
            size.height * .13,
            size.width * .5,
            size.height * .5,
          )
          ..cubicTo(
            size.width * .57,
            size.height * .88,
            size.width * .82,
            size.height * .9,
            size.width * .92,
            size.height * .46,
          )
          ..cubicTo(
            size.width * .8,
            size.height * .09,
            size.width * .58,
            size.height * .14,
            size.width * .5,
            size.height * .5,
          )
          ..cubicTo(
            size.width * .4,
            size.height * .86,
            size.width * .18,
            size.height * .88,
            size.width * .08,
            size.height * .54,
          );
        canvas.drawPath(orbit, glow);
        canvas.drawPath(orbit, stroke);
        break;
      case _KpopEmblemKind.prism:
        final prism = Path()
          ..moveTo(size.width * .13, size.height * .76)
          ..lineTo(size.width * .5, size.height * .12)
          ..lineTo(size.width * .87, size.height * .76)
          ..lineTo(size.width * .65, size.height * .76)
          ..lineTo(size.width * .5, size.height * .49)
          ..lineTo(size.width * .34, size.height * .76)
          ..close();
        canvas.drawPath(prism, glow);
        canvas.drawPath(prism, fill);
        break;
      case _KpopEmblemKind.monogram:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _KpopEmblemPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.accent != accent;
  }
}

class _KpopIdentityArtworkPainter extends CustomPainter {
  const _KpopIdentityArtworkPainter({required this.accent, required this.seed});

  final Color accent;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = accent.withValues(alpha: .22);
    final softStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = accent.withValues(alpha: .05);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .34;
    canvas.drawCircle(center, radius, softStroke);
    canvas.drawCircle(center, radius, stroke);

    final variant = seed % 3;
    if (variant == 0) {
      canvas.drawLine(
        Offset(size.width * .2, size.height * .72),
        Offset(size.width * .78, size.height * .25),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * .28, size.height * .8),
        Offset(size.width * .86, size.height * .33),
        stroke,
      );
    } else if (variant == 1) {
      final diamond = Path()
        ..moveTo(size.width * .5, size.height * .13)
        ..lineTo(size.width * .84, size.height * .5)
        ..lineTo(size.width * .5, size.height * .87)
        ..lineTo(size.width * .16, size.height * .5)
        ..close();
      canvas.drawPath(diamond, stroke);
    } else {
      final arcRect = Rect.fromCircle(center: center, radius: radius * 1.18);
      canvas.drawArc(arcRect, -.6, 2.05, false, stroke);
      canvas.drawArc(arcRect, 2.55, 2.05, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _KpopIdentityArtworkPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.seed != seed;
  }
}

class _NewsTopicSearchField extends StatelessWidget {
  const _NewsTopicSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextFormField(
              key: const ValueKey('news-topic-search'),
              initialValue: value,
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              cursorColor: AppTheme.rose,
              decoration: InputDecoration(
                hintText: 'Buscar noticias, grupos o artistas',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsIntroPanel extends StatelessWidget {
  const _NewsIntroPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.nightSoft.withValues(alpha: 0.94),
            AppTheme.rose.withValues(alpha: 0.16),
            AppTheme.cyan.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: -8,
            child: Opacity(
              opacity: 0.92,
              child: Image.asset(
                'assets/brand/hally_mascot_news_reader.png',
                width: 116,
                height: 116,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14.5,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.11),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppTheme.rose, AppTheme.cyan],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cyan.withValues(alpha: 0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.newspaper_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Elegí tus grupos y filtrá por el tipo de novedad que querés mirar.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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

class _NewsMiniHeading extends StatelessWidget {
  const _NewsMiniHeading({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null && onAction == null)
          Text(
            action!,
            style: const TextStyle(
              color: AppTheme.violet,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        if (action != null && onAction != null)
          TextButton(
            key: const ValueKey('news-edit-followed-topics'),
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.violet,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class _NewsTopicSaveException implements Exception {
  const _NewsTopicSaveException(this.message);

  final String message;
}

class NewsTopicEditorSheet extends StatefulWidget {
  const NewsTopicEditorSheet({
    super.key,
    required this.entities,
    required this.initialSelection,
    required this.onSave,
  });

  final List<KpopEntity> entities;
  final Set<String> initialSelection;
  final Future<void> Function(Set<String>) onSave;

  @override
  State<NewsTopicEditorSheet> createState() => _NewsTopicEditorSheetState();
}

class _NewsTopicEditorSheetState extends State<NewsTopicEditorSheet> {
  late final Set<String> _selectedIds;
  String _query = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelection);
  }

  List<KpopEntity> get _visibleEntities {
    final query = _query.trim().toLowerCase();
    final entities = widget.entities
        .where((entity) {
          if (query.isEmpty) return true;
          return entity.name.toLowerCase().contains(query) ||
              entity.typeLabel.toLowerCase().contains(query) ||
              entity.aliases.any(
                (alias) => alias.toLowerCase().contains(query),
              );
        })
        .toList(growable: false);
    entities.sort((a, b) {
      final aSelected = _selectedIds.contains(a.id) ? 0 : 1;
      final bSelected = _selectedIds.contains(b.id) ? 0 : 1;
      final selectionOrder = aSelected.compareTo(bSelected);
      if (selectionOrder != 0) return selectionOrder;
      final typeOrder = a.type.index.compareTo(b.type.index);
      if (typeOrder != 0) return typeOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entities;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(Set<String>.from(_selectedIds));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on _NewsTopicSaveException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No pudimos guardar tus temas. Probá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entities = _visibleEntities;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: constraints.maxHeight * 0.88,
            child: Material(
              color: AppTheme.night,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                side: BorderSide(
                  color: AppTheme.violet.withValues(alpha: 0.42),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Editar temas de noticias',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Elegí grupos, idols o solistas para personalizar Noticias.',
                                style: TextStyle(
                                  color: Color(0xFFAFB2C3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      key: const ValueKey('news-topic-editor-search'),
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar grupo, idol o solista',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppTheme.panelRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: AppTheme.stroke.withValues(alpha: 0.8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: AppTheme.stroke.withValues(alpha: 0.8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppTheme.cyan),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedIds.length} seleccionados',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '“Todos” no se guarda como tema',
                            maxLines: 2,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.52),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.rose,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: entities.isEmpty
                        ? const Center(
                            child: Text(
                              'No encontramos temas con ese nombre.',
                              style: TextStyle(
                                color: Color(0xFFAFB2C3),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                            itemCount: entities.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (context, index) {
                              final entity = entities[index];
                              final selected = _selectedIds.contains(entity.id);
                              return CheckboxListTile(
                                key: ValueKey(
                                  'news-topic-editor-option-${entity.id}',
                                ),
                                value: selected,
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value ?? false) {
                                            _selectedIds.add(entity.id);
                                          } else {
                                            _selectedIds.remove(entity.id);
                                          }
                                        });
                                      },
                                activeColor: AppTheme.rose,
                                checkColor: Colors.white,
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                secondary: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.violet.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(switch (entity.type) {
                                    KpopEntityType.group =>
                                      Icons.groups_2_rounded,
                                    KpopEntityType.idol => Icons.person_rounded,
                                    KpopEntityType.artist =>
                                      Icons.mic_external_on_rounded,
                                  }, color: AppTheme.cyan),
                                ),
                                title: Text(
                                  entity.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  entity.typeLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('news-topic-editor-cancel'),
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('news-topic-editor-save'),
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.rose,
                              foregroundColor: Colors.white,
                            ),
                            child: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsEmptyStrip extends StatelessWidget {
  const _NewsEmptyStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NewsFollowedTopicRail extends StatelessWidget {
  const _NewsFollowedTopicRail({
    required this.topics,
    required this.selected,
    required this.onSelected,
  });

  final List<KpopEntity> topics;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _NewsTopicPill(
            label: 'Todos',
            selected: selected == 'Todos',
            onTap: () => onSelected('Todos'),
          ),
          const SizedBox(width: 8),
          for (final topic in topics) ...[
            _NewsTopicPill(
              label: topic.name,
              selected: selected == topic.name,
              onTap: () => onSelected(topic.name),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _NewsTopicPill extends StatelessWidget {
  const _NewsTopicPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(colors: [AppTheme.rose, AppTheme.cyan])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.28)
                : AppTheme.rose.withValues(alpha: 0.34),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.cyan.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.night : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.check_circle_rounded,
              color: selected ? AppTheme.night : AppTheme.rose,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsFilterRail extends StatelessWidget {
  const _NewsFilterRail({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _items = [
    _NewsFilterItem('Para vos', Icons.auto_awesome_rounded),
    _NewsFilterItem('Siguiendo', Icons.favorite_border_rounded),
    _NewsFilterItem('Últimas', Icons.schedule_rounded),
    _NewsFilterItem('Oficiales', Icons.campaign_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final item = _items[index];
          final isSelected = selected == item.label;
          return InkWell(
            onTap: () => onSelected(item.label),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSelected
                    ? AppTheme.cyan.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.cyan.withValues(alpha: 0.34)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? AppTheme.cyan
                        : Colors.white.withValues(alpha: 0.54),
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewsFilterItem {
  const _NewsFilterItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _FollowTopicChip extends StatelessWidget {
  const _FollowTopicChip({
    required this.label,
    required this.followed,
    required this.followerCount,
    required this.followerCountLoading,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool followed;
  final int? followerCount;
  final bool followerCountLoading;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: busy ? null : onTap,
      avatar: Icon(
        followed ? Icons.check_rounded : Icons.add_rounded,
        color: Colors.white,
        size: 17,
      ),
      label: Text(
        followed
            ? 'Siguiendo $label'
            : followerCountLoading
            ? label
            : '$label · ${followerCount == null ? '—' : formatSpanishInteger(followerCount!)}',
      ),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
      backgroundColor: followed
          ? AppTheme.rose.withValues(alpha: 0.58)
          : AppTheme.nightSoft.withValues(alpha: 0.82),
      side: BorderSide(
        color: (followed ? AppTheme.rose : AppTheme.cyan).withValues(
          alpha: 0.32,
        ),
      ),
    );
  }
}

class _EntityFilterPanel extends StatelessWidget {
  const _EntityFilterPanel({
    required this.selectedRegion,
    required this.selectedType,
    required this.onRegion,
    required this.onType,
    required this.onSuggest,
  });

  final String selectedRegion;
  final DiscoverEntityType? selectedType;
  final ValueChanged<String> onRegion;
  final ValueChanged<DiscoverEntityType?> onType;
  final VoidCallback onSuggest;

  static const _regions = ['Todos', 'Argentina', 'Chile', 'LATAM', 'Global'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Exploración dinámica', style: _compactTitleStyle),
              ),
              TextButton.icon(
                onPressed: onSuggest,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Sugerir'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _regions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final region = _regions[index];
                return _DiscoverChip(
                  label: region,
                  selected: selectedRegion == region,
                  compact: true,
                  onTap: () => onRegion(region),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DiscoverEntityType.values.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _DiscoverChip(
                    label: 'Todos los tipos',
                    selected: selectedType == null,
                    compact: true,
                    onTap: () => onType(null),
                  );
                }
                final type = DiscoverEntityType.values[index - 1];
                return _DiscoverChip(
                  label: type.label,
                  selected: selectedType == type,
                  compact: true,
                  onTap: () => onType(type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonFrame extends StatelessWidget {
  const _NeonFrame({required this.child, this.radius = 20});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            AppTheme.cyan.withValues(alpha: 0.42),
            AppTheme.rose.withValues(alpha: 0.34),
            AppTheme.violet.withValues(alpha: 0.48),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(margin: const EdgeInsets.all(1), child: child),
    );
  }
}

class _GradientPill extends StatelessWidget {
  const _GradientPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.rose.withValues(alpha: 0.88),
            AppTheme.violet.withValues(alpha: 0.72),
            AppTheme.cyan.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(label, style: _pillTextStyle),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.backgroundAsset,
    this.mascotAsset,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? backgroundAsset;
  final String? mascotAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF05060B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.13),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (backgroundAsset != null)
              Positioned.fill(
                child: Image.asset(
                  backgroundAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.night.withValues(alpha: .06),
                      color.withValues(alpha: .04),
                      AppTheme.night.withValues(alpha: .78),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2,
              top: 22,
              child: IgnorePointer(
                child: Opacity(
                  opacity: mascotAsset == null ? 0.12 : 0.96,
                  child: mascotAsset == null
                      ? Icon(
                          icon,
                          color: color.withValues(alpha: 0.22),
                          size: 118,
                        )
                      : Image.asset(
                          mascotAsset!,
                          width: 94,
                          height: 104,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                ),
              ),
            ),
            Positioned(
              left: 13,
              top: 13,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.night.withValues(alpha: .58),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: .28)),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 102,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF030409).withValues(alpha: .96),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 17, color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _miniMutedStyle,
                  ),
                ],
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

class _EditorialNewsStack extends StatelessWidget {
  const _EditorialNewsStack({required this.items, required this.onTap});

  final List<DiscoverNews> items;
  final ValueChanged<DiscoverNews> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final lead = items.first;
    return Column(
      children: [
        _EditorialNewsLead(item: lead, onTap: () => onTap(lead)),
        const SizedBox(height: 10),
        ...items
            .skip(1)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NewsCard(item: item, onTap: () => onTap(item)),
              ),
            ),
      ],
    );
  }
}

class _EditorialNewsLead extends StatelessWidget {
  const _EditorialNewsLead({required this.item, required this.onTap});

  final DiscoverNews item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 1.42,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(item.imageAsset, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      AppTheme.night.withValues(alpha: 0.86),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _GradientPill(
                          label: item.editorialBadge,
                          icon: Icons.bolt_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(item.publishedLabel, style: _miniMutedStyle),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.displayTitle,
                      style: _editorialTitleStyle,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${item.entityLabel} · ${item.displaySource}',
                      style: _mutedStyle,
                      maxLines: 1,
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

class _GroupRailCard extends StatelessWidget {
  const _GroupRailCard({required this.group, required this.onTap});

  final DiscoverGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: _PressableScale(
        onTap: onTap,
        borderRadius: 18,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LicensedDiscoverVisual(
                title: group.name,
                subtitle: group.fandom,
                imageAsset: group.imageAsset,
                imageUrl: group.imageUrl,
                imageSource: group.imageSource,
                imageLicense: group.imageLicense,
                attribution: group.attribution,
                author: group.author,
                licenseUrl: group.licenseUrl,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      AppTheme.night.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _GradientPill(label: group.fandom),
              ),
              Positioned(
                left: 11,
                right: 11,
                bottom: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: _railTitleStyle, maxLines: 2),
                    const SizedBox(height: 3),
                    Text(
                      '${group.idols.length} integrantes',
                      style: _miniMutedStyle,
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

class _GroupListCard extends StatelessWidget {
  const _GroupListCard({required this.group, required this.onTap});

  final DiscoverGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ImageListCard(
      key: ValueKey('discover-group-${group.id}'),
      imageAsset: group.imageAsset,
      visual: LicensedDiscoverVisual(
        title: group.name,
        subtitle: group.fandom,
        imageAsset: group.imageAsset,
        imageUrl: group.imageUrl,
        imageSource: group.imageSource,
        imageLicense: group.imageLicense,
        attribution: group.attribution,
        author: group.author,
        licenseUrl: group.licenseUrl,
      ),
      eyebrow: '${group.fandom} · ${group.debut}',
      title: group.name,
      subtitle: group.style,
      badge: '${group.idols.length} idols',
      accent: AppTheme.cyan,
      onTap: onTap,
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({required this.entity, required this.onTap});

  final DiscoverArtistEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _entityColor(entity.status);
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 78,
                height: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LicensedDiscoverVisual(
                      title: entity.name,
                      subtitle: entity.fandom,
                      imageAsset: entity.imageAsset,
                      imageUrl: entity.imageUrl,
                      imageSource: entity.imageSource,
                      imageLicense: entity.imageLicense,
                      attribution: entity.attribution,
                      author: entity.author,
                      licenseUrl: entity.licenseUrl,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.night.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 7,
                      child: _SmallGlassBadge(
                        label: entity.type.label,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entity.status.label, style: _eyebrowStyle),
                  const SizedBox(height: 4),
                  Text(
                    entity.name,
                    style: _compactTitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entity.region} · ${entity.fandom}',
                    style: _mutedStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(_entityIcon(entity.type), color: color),
          ],
        ),
      ),
    );
  }
}

class _IdolCard extends StatelessWidget {
  const _IdolCard({required this.idol, required this.onTap});

  final DiscoverIdol idol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final group = discoverGroups.firstWhere((item) => item.id == idol.groupId);
    return _ImageListCard(
      key: ValueKey('discover-idol-list-${idol.id}'),
      imageAsset: idol.imageAsset,
      visual: LicensedDiscoverVisual(
        title: idol.name,
        subtitle: group.name,
        imageAsset: idol.imageAsset,
        imageUrl: idol.imageUrl,
        imageSource: idol.imageSource,
        imageLicense: idol.imageLicense,
        attribution: idol.attribution,
        author: idol.author,
        licenseUrl: idol.licenseUrl,
      ),
      eyebrow: group.name,
      title: idol.name,
      subtitle: idol.role,
      badge: idol.country,
      accent: AppTheme.rose,
      onTap: onTap,
    );
  }
}

enum _NewsCardLayout { featured, compact, panorama }

_NewsCardLayout _newsCardLayoutForIndex(int index) {
  if (index == 0) return _NewsCardLayout.featured;
  return index.isOdd ? _NewsCardLayout.compact : _NewsCardLayout.panorama;
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.onTap,
    this.layout = _NewsCardLayout.compact,
  });

  final DiscoverNews item;
  final VoidCallback onTap;
  final _NewsCardLayout layout;

  Color get _accent => switch (item.editorialBadge) {
    'Oficial' || 'Confirmado' => AppTheme.cyan,
    'Rumor' => AppTheme.amber,
    'En desarrollo' => AppTheme.violet,
    _ => AppTheme.rose,
  };

  BoxDecoration _cardDecoration(double radius) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.panelRaised.withValues(alpha: 0.96),
          AppTheme.panel.withValues(alpha: 0.99),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _accent.withValues(alpha: 0.24)),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: 0.09),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _sourceRow({bool showLink = true}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${item.displaySource} · ${item.publishedLabel}',
            style: _eyebrowStyle.copyWith(color: _accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showLink && item.hasOriginalLink) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.58),
          ),
        ],
      ],
    );
  }

  Widget _tags({int max = 3}) {
    if (item.displayTags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in item.displayTags.take(max))
          _SmallGlassBadge(label: tag, color: AppTheme.violet),
      ],
    );
  }

  // Legacy layout helpers remain available for future editorial variants.
  // ignore: unused_element
  Widget _buildFeatured() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.62,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NewsVisual(item: item, accent: _accent),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.52, 1],
                      colors: [
                        AppTheme.night.withValues(alpha: 0.05),
                        AppTheme.night.withValues(alpha: 0.14),
                        AppTheme.night.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Row(
                    children: [
                      _SmallGlassBadge(
                        label: item.editorialBadge,
                        color: _accent,
                      ),
                      const SizedBox(width: 7),
                      _SmallGlassBadge(
                        label: 'Destacada',
                        color: AppTheme.rose,
                      ),
                    ],
                  ),
                ),
                if (item.hasOriginalLink)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.night.withValues(alpha: 0.68),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.displaySource} · ${item.publishedLabel}',
                        style: _eyebrowStyle.copyWith(color: _accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.displayTitle,
                        style: _editorialTitleStyle.copyWith(
                          fontSize: 24,
                          height: 1.08,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.cardSummary.isNotEmpty)
                  Text(
                    item.cardSummary,
                    style: _mutedStyle.copyWith(height: 1.38),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.displayTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _tags(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: _cardDecoration(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NewsThumbnail(
            item: item,
            badge: item.editorialBadge,
            accent: _accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sourceRow(),
                const SizedBox(height: 7),
                Text(
                  item.displayTitle,
                  style: _compactTitleStyle.copyWith(height: 1.18),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.cardSummary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.cardSummary,
                    style: _mutedStyle.copyWith(height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.displayTags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _tags(max: 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPanorama() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2.08,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NewsVisual(item: item, accent: _accent),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.night.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _SmallGlassBadge(
                    label: item.editorialBadge,
                    color: _accent,
                  ),
                ),
                if (item.hasOriginalLink)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sourceRow(showLink: false),
                const SizedBox(height: 7),
                Text(
                  item.displayTitle,
                  style: _compactTitleStyle.copyWith(
                    fontSize: 18,
                    height: 1.18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.cardSummary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.cardSummary,
                    style: _mutedStyle.copyWith(height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.displayTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _tags(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SharedNewsPostCard(
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
      onOpen: (_) => onTap(),
    );
    /*
    final content = switch (layout) {
      _NewsCardLayout.featured => _buildFeatured(),
      _NewsCardLayout.compact => _buildCompact(),
      _NewsCardLayout.panorama => _buildPanorama(),
    };
    return Semantics(
      button: true,
      label: '${item.displayTitle}, ${item.displaySource}',
      child: _PressableScale(
        onTap: onTap,
        borderRadius: layout == _NewsCardLayout.compact ? 18 : 20,
        child: content,
      ),
    );
    */
  }
}

class _NewsThumbnail extends StatelessWidget {
  const _NewsThumbnail({
    required this.item,
    required this.badge,
    required this.accent,
  });

  final DiscoverNews item;
  final String badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 108,
        height: 148,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NewsVisual(item: item, accent: accent),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.night.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 7,
              right: 7,
              bottom: 7,
              child: _SmallGlassBadge(label: badge, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsVisual extends StatelessWidget {
  const _NewsVisual({required this.item, required this.accent});

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
    final normalized = [
      item.displayTitle,
      item.cardSummary,
      ...item.displayTags,
    ].join(' ').toLowerCase();
    final asset =
        normalized.contains('concierto') ||
            normalized.contains('festival') ||
            normalized.contains('show') ||
            normalized.contains('gira')
        ? 'assets/brand/hally_discover_neon_backdrop_v1.jpg'
        : normalized.contains('grupo') ||
              normalized.contains('debut') ||
              normalized.contains('comeback')
        ? 'assets/brand/hally_discover_groups_stage_v2.jpg'
        : 'assets/brand/hally_discover_news_globe_v2.jpg';
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.34),
                  AppTheme.violet.withValues(alpha: 0.2),
                  AppTheme.nightSoft,
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.05),
                AppTheme.night.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsLoadingList extends StatelessWidget {
  const _NewsLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 154,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.nightSoft.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                _NewsSkeletonBlock(width: 98, height: 132, radius: 14),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NewsSkeletonBlock(height: 10, widthFactor: 0.72),
                      SizedBox(height: 12),
                      _NewsSkeletonBlock(height: 18),
                      SizedBox(height: 7),
                      _NewsSkeletonBlock(height: 18, widthFactor: 0.84),
                      SizedBox(height: 12),
                      _NewsSkeletonBlock(height: 11),
                      SizedBox(height: 7),
                      _NewsSkeletonBlock(height: 11, widthFactor: 0.68),
                    ],
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

class _NewsSkeletonBlock extends StatelessWidget {
  const _NewsSkeletonBlock({
    required this.height,
    this.width,
    this.widthFactor,
    this.radius = 6,
  });

  final double height;
  final double? width;
  final double? widthFactor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (widthFactor == null) return block;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: block,
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.item, required this.onTap});

  final DiscoverCommunity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      icon: Icons.forum_outlined,
      eyebrow: '${item.region} · ${item.members}',
      title: item.name,
      subtitle: '${item.fandom} · ${item.activity}',
      accent: AppTheme.violet,
      badge: 'Unirse',
      onTap: onTap,
    );
  }
}

class _BetaCommunityCard extends StatelessWidget {
  const _BetaCommunityCard({
    required this.item,
    required this.joined,
    required this.onOpen,
    required this.onToggle,
  });

  final DiscoverCommunity item;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visual = _CommunityVisualTheme.forCommunity(item);
    final membersLabel = _communityMembersLabel(item.members);
    final isCountryCommunity =
        item.city.trim().isEmpty && item.province.trim().isEmpty;

    return SizedBox(
      height: isCountryCommunity ? 206 : 174,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CommunityPlaceBackdrop(visual: visual),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommunityLocationBadge(
                        label: item.region,
                        visual: visual,
                      ),
                      const Spacer(),
                      Text(
                        item.name,
                        style: _compactTitleStyle.copyWith(
                          fontSize: isCountryCommunity ? 23 : 20,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 12),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.fandom,
                        style: _mutedStyle.copyWith(
                          color: Colors.white.withValues(alpha: .78),
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            color: Colors.white.withValues(alpha: .66),
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            membersLabel,
                            style: _miniMutedStyle.copyWith(
                              color: Colors.white.withValues(alpha: .76),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 38,
                            child: OutlinedButton(
                              onPressed: joined ? onOpen : onToggle,
                              style: _communityJoinButtonStyle(visual),
                              child: Text(joined ? 'Entrar al chat' : 'Unirme'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityActionTile extends StatelessWidget {
  const _CommunityActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: .2),
                AppTheme.nightSoft.withValues(alpha: .9),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: .5)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: _miniMutedStyle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

String _communityMembersLabel(String rawCount) {
  final normalized = rawCount.replaceAll('.', '').replaceAll(',', '').trim();
  final count = int.tryParse(normalized);
  if (count == 1) return '1 miembro';
  return '$rawCount miembros';
}

ButtonStyle _communityJoinButtonStyle(_CommunityVisualTheme visual) {
  return OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: Colors.black.withValues(alpha: .5),
    side: BorderSide(color: visual.highlight.withValues(alpha: .84)),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
  );
}

enum _CommunityPlaceArt {
  argentina,
  buenosAires,
  cityGrid,
  mexico,
  monterrey,
  guadalajara,
  chile,
  brazil,
  generic,
}

class _CommunityVisualTheme {
  const _CommunityVisualTheme({
    required this.primary,
    required this.secondary,
    required this.highlight,
    required this.art,
    this.assetPath,
  });

  final Color primary;
  final Color secondary;
  final Color highlight;
  final _CommunityPlaceArt art;
  final String? assetPath;

  static _CommunityVisualTheme forCommunity(DiscoverCommunity item) {
    final location = [
      item.name,
      item.region,
      item.city,
      item.province,
      item.country,
    ].join(' ');
    return forLocation(location);
  }

  static _CommunityVisualTheme forLocation(String rawLocation) {
    final location = rawLocation.toLowerCase();

    if (location.contains('buenos aires')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFF725CFF),
        secondary: Color(0xFF182758),
        highlight: Color(0xFF65E4FF),
        art: _CommunityPlaceArt.buenosAires,
        assetPath: 'assets/brand/community_buenos_aires_v2.png',
      );
    }
    if (location.contains('caba')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFFFF2D9A),
        secondary: Color(0xFF46154D),
        highlight: Color(0xFFFF73CE),
        art: _CommunityPlaceArt.cityGrid,
        assetPath: 'assets/brand/community_caba_v2.png',
      );
    }
    if (location.contains('monterrey')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFFFF4F9A),
        secondary: Color(0xFF263B62),
        highlight: Color(0xFF62E3D5),
        art: _CommunityPlaceArt.monterrey,
        assetPath: 'assets/brand/community_mexico_country_v1.png',
      );
    }
    if (location.contains('guadalajara')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFFFF4C96),
        secondary: Color(0xFF51214D),
        highlight: Color(0xFFFFC857),
        art: _CommunityPlaceArt.guadalajara,
        assetPath: 'assets/brand/community_mexico_country_v1.png',
      );
    }
    if (location.contains('méxico') ||
        location.contains('mexico') ||
        location.contains('cdmx')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFFFF4F9A),
        secondary: Color(0xFF263B62),
        highlight: Color(0xFF62E3D5),
        art: _CommunityPlaceArt.mexico,
        assetPath: 'assets/brand/community_mexico_country_v1.png',
      );
    }
    if (location.contains('chile')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFF5B7CFF),
        secondary: Color(0xFF152B5C),
        highlight: Color(0xFFFF5B83),
        art: _CommunityPlaceArt.chile,
        assetPath: 'assets/brand/community_chile_country_v1.png',
      );
    }
    if (location.contains('perú') || location.contains('peru')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFFFF4F9A),
        secondary: Color(0xFF3D214C),
        highlight: Color(0xFFFFC857),
        art: _CommunityPlaceArt.generic,
        assetPath: 'assets/brand/community_peru_country_v1.png',
      );
    }
    if (location.contains('uruguay')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFF65E4FF),
        secondary: Color(0xFF1B315E),
        highlight: Color(0xFFA879FF),
        art: _CommunityPlaceArt.generic,
        assetPath: 'assets/brand/community_uruguay_country_v1.png',
      );
    }
    if (location.contains('brasil') || location.contains('brazil')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFF17C98B),
        secondary: Color(0xFF174F4A),
        highlight: Color(0xFFFFD34E),
        art: _CommunityPlaceArt.brazil,
      );
    }
    if (location.contains('argentina')) {
      return const _CommunityVisualTheme(
        primary: Color(0xFF65E4FF),
        secondary: Color(0xFF234F7C),
        highlight: Color(0xFFFFD36A),
        art: _CommunityPlaceArt.argentina,
        assetPath: 'assets/brand/community_argentina_country_v2.png',
      );
    }
    return const _CommunityVisualTheme(
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF23204B),
      highlight: Color(0xFFFF2D9A),
      art: _CommunityPlaceArt.generic,
    );
  }
}

class _CommunityLocationBadge extends StatelessWidget {
  const _CommunityLocationBadge({
    required this.label,
    required this.visual,
    this.compact = false,
  });

  final String label;
  final _CommunityVisualTheme visual;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 210 : 270),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.primary.withValues(alpha: .54)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            color: visual.highlight,
            size: compact ? 13 : 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPlaceBackdrop extends StatelessWidget {
  const _CommunityPlaceBackdrop({required this.visual});

  final _CommunityVisualTheme visual;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.secondary,
            AppTheme.night,
            visual.primary.withValues(alpha: .34),
          ],
          stops: const [0, .62, 1],
        ),
        border: Border.all(color: visual.primary.withValues(alpha: .62)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (visual.assetPath case final assetPath?)
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            )
          else
            CustomPaint(painter: _CommunityPlacePainter(visual)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.night.withValues(alpha: .88),
                  AppTheme.night.withValues(alpha: .48),
                  AppTheme.night.withValues(alpha: .08),
                ],
                stops: const [0, .52, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .04),
                  AppTheme.night.withValues(alpha: .06),
                  AppTheme.night.withValues(alpha: .72),
                ],
                stops: const [0, .48, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: FractionallySizedBox(
              widthFactor: .27,
              heightFactor: .68,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Image.asset(
                  'assets/brand/hally_mascot_community.png',
                  alignment: Alignment.topRight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPlacePainter extends CustomPainter {
  const _CommunityPlacePainter(this.visual);

  final _CommunityVisualTheme visual;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = visual.highlight.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final solid = Paint()
      ..color = visual.primary.withValues(alpha: .22)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = visual.highlight.withValues(alpha: .24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    switch (visual.art) {
      case _CommunityPlaceArt.argentina:
        final sun = Offset(size.width * .78, size.height * .28);
        canvas.drawCircle(sun, size.shortestSide * .09, solid);
        canvas.drawCircle(sun, size.shortestSide * .13, glow);
        for (final delta in const [
          Offset(0, -34),
          Offset(0, 34),
          Offset(-34, 0),
          Offset(34, 0),
          Offset(-24, -24),
          Offset(24, 24),
          Offset(24, -24),
          Offset(-24, 24),
        ]) {
          canvas.drawLine(sun + delta * .58, sun + delta, line);
        }
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * .35, size.height * .06),
            radius: size.width * .72,
          ),
          .45,
          1.8,
          false,
          glow..strokeWidth = 3,
        );
        break;
      case _CommunityPlaceArt.buenosAires:
        final base = size.height * .7;
        for (var i = 0; i < 8; i++) {
          final width = size.width * .065;
          final left = size.width * (.44 + i * .07);
          final height = size.height * (.14 + (i % 3) * .055);
          canvas.drawRect(
            Rect.fromLTWH(left, base - height, width, height),
            solid,
          );
        }
        final obelisk = Path()
          ..moveTo(size.width * .31, base)
          ..lineTo(size.width * .35, size.height * .22)
          ..lineTo(size.width * .39, base)
          ..close();
        canvas.drawPath(obelisk, solid);
        canvas.drawPath(obelisk, glow);
        canvas.drawLine(
          Offset(0, base),
          Offset(size.width, base),
          line..strokeWidth = 2,
        );
        break;
      case _CommunityPlaceArt.cityGrid:
        for (var i = -2; i < 9; i++) {
          final dx = size.width * i / 7;
          canvas.drawLine(
            Offset(dx, 0),
            Offset(dx + size.width * .32, size.height),
            line,
          );
        }
        for (var i = 0; i < 7; i++) {
          final dy = size.height * i / 6;
          canvas.drawLine(
            Offset(0, dy),
            Offset(size.width, dy + size.height * .08),
            line,
          );
        }
        break;
      case _CommunityPlaceArt.mexico:
        final base = size.height * .7;
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * .73,
            size.height * .3,
            size.width * .035,
            base - size.height * .3,
          ),
          solid,
        );
        canvas.drawCircle(
          Offset(size.width * .748, size.height * .25),
          size.shortestSide * .055,
          solid,
        );
        final wings = Path()
          ..moveTo(size.width * .748, size.height * .27)
          ..lineTo(size.width * .65, size.height * .18)
          ..lineTo(size.width * .72, size.height * .31)
          ..lineTo(size.width * .79, size.height * .31)
          ..lineTo(size.width * .85, size.height * .18)
          ..close();
        canvas.drawPath(wings, glow);
        break;
      case _CommunityPlaceArt.monterrey:
      case _CommunityPlaceArt.chile:
        final mountains = Path()
          ..moveTo(0, size.height * .62)
          ..lineTo(size.width * .18, size.height * .34)
          ..lineTo(size.width * .31, size.height * .55)
          ..lineTo(size.width * .48, size.height * .2)
          ..lineTo(size.width * .63, size.height * .52)
          ..lineTo(size.width * .82, size.height * .28)
          ..lineTo(size.width, size.height * .6);
        canvas.drawPath(mountains, glow..strokeWidth = 2.4);
        break;
      case _CommunityPlaceArt.guadalajara:
        final base = size.height * .68;
        for (final centerX in [size.width * .68, size.width * .84]) {
          final tower = Path()
            ..moveTo(centerX - 14, base)
            ..lineTo(centerX - 8, size.height * .3)
            ..lineTo(centerX, size.height * .17)
            ..lineTo(centerX + 8, size.height * .3)
            ..lineTo(centerX + 14, base)
            ..close();
          canvas.drawPath(tower, solid);
          canvas.drawPath(tower, glow);
        }
        canvas.drawArc(
          Rect.fromLTWH(
            size.width * .65,
            size.height * .46,
            size.width * .22,
            size.height * .25,
          ),
          3.14,
          3.14,
          false,
          glow,
        );
        break;
      case _CommunityPlaceArt.brazil:
        canvas.drawCircle(
          Offset(size.width * .76, size.height * .3),
          size.shortestSide * .15,
          glow..strokeWidth = 3,
        );
        canvas.drawArc(
          Rect.fromLTWH(
            size.width * .46,
            size.height * .08,
            size.width * .56,
            size.height * .58,
          ),
          .2,
          2.3,
          false,
          line..strokeWidth = 2,
        );
        break;
      case _CommunityPlaceArt.generic:
        canvas.drawCircle(
          Offset(size.width * .76, size.height * .25),
          size.shortestSide * .18,
          glow..strokeWidth = 3,
        );
        canvas.drawCircle(
          Offset(size.width * .86, size.height * .44),
          size.shortestSide * .09,
          line,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CommunityPlacePainter oldDelegate) {
    return oldDelegate.visual.art != visual.art ||
        oldDelegate.visual.primary != visual.primary ||
        oldDelegate.visual.secondary != visual.secondary;
  }
}

class _CreateCommunityPanel extends StatelessWidget {
  const _CreateCommunityPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 20,
      child: Container(
        key: const ValueKey('discover-create-community'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.violet.withValues(alpha: 0.34),
              AppTheme.cyan.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.07),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.26)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_home_work_outlined,
                color: AppTheme.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Armar comunidad',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Creá un espacio por ciudad, fandom o proyecto fan.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _CommunityComposerSheet extends StatefulWidget {
  const _CommunityComposerSheet({required this.onCreate});

  final Future<DiscoverCommunity> Function(DiscoverCommunity community)
  onCreate;

  @override
  State<_CommunityComposerSheet> createState() =>
      _CommunityComposerSheetState();
}

class _CommunityComposerSheetState extends State<_CommunityComposerSheet> {
  final _nameController = TextEditingController();
  final _countryController = TextEditingController(text: 'Argentina');
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _fandomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final String _privacy = 'Pública';
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _fandomController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _nameController.text.trim();
    final country = _countryController.text.trim();
    final province = _provinceController.text.trim();
    final city = _cityController.text.trim();
    final fandom = _fandomController.text.trim();
    final description = _descriptionController.text.trim();
    if ([name, country, fandom, description].any((value) => value.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá nombre, país, fandom y descripción.'),
        ),
      );
      return;
    }
    final region = [if (city.isNotEmpty) city, province, country].join(', ');
    final createdAt = DateTime.now();
    setState(() => _creating = true);
    try {
      final created = await widget.onCreate(
        DiscoverCommunity(
          id: 'community-${createdAt.microsecondsSinceEpoch}',
          name: name,
          region: region,
          members: '1',
          activity: 'Nueva',
          fandom: fandom,
          description: description,
          posts: const [],
          country: country,
          province: province,
          city: city,
          privacy: _privacy,
          createdBy: 'current-user',
          createdAt: createdAt,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _refreshPreview(String _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.96;
    final visibleHeight = media.size.height - media.viewInsets.bottom - 8;
    final sheetHeight = visibleHeight < maxHeight ? visibleHeight : maxHeight;
    final locationParts = [
      _cityController.text.trim(),
      _provinceController.text.trim(),
      _countryController.text.trim(),
    ].where((value) => value.isNotEmpty).toList();
    final locationLabel = locationParts.isEmpty
        ? 'Elegí una ubicación'
        : locationParts.join(', ');
    final visual = _CommunityVisualTheme.forLocation(locationLabel);
    final previewName = _nameController.text.trim().isEmpty
        ? 'Tu comunidad'
        : _nameController.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF070B17),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.violet.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.violet.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.11),
                          ),
                        ),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva comunidad',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Creá un espacio para conectar y compartir.',
                              style: TextStyle(
                                color: Color(0xFFAEB6C9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _CommunityFormProgress(),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CommunityComposerPreview(
                          name: previewName,
                          location: locationLabel,
                          visual: visual,
                        ),
                        const SizedBox(height: 22),
                        const _CommunityFormSection(
                          icon: Icons.auto_awesome_outlined,
                          title: 'Identidad',
                          subtitle:
                              'Dale un nombre claro y fácil de encontrar.',
                        ),
                        const SizedBox(height: 10),
                        _CommunityField(
                          key: const ValueKey('community-name'),
                          controller: _nameController,
                          label: 'Nombre de la comunidad',
                          hint: 'Ej. ARMY Rosario',
                          prefixIcon: Icons.groups_2_outlined,
                          maxLength: 40,
                          onChanged: _refreshPreview,
                        ),
                        const SizedBox(height: 20),
                        const _CommunityFormSection(
                          icon: Icons.location_on_outlined,
                          title: 'Ubicación',
                          subtitle:
                              'La portada se adapta automáticamente al país.',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _CommunityField(
                                key: const ValueKey('community-country'),
                                controller: _countryController,
                                label: 'País',
                                hint: 'Argentina',
                                prefixIcon: Icons.public_rounded,
                                onChanged: _refreshPreview,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CommunityField(
                                key: const ValueKey('community-province'),
                                controller: _provinceController,
                                label: 'Provincia / región',
                                hint: 'Buenos Aires',
                                prefixIcon: Icons.map_outlined,
                                onChanged: _refreshPreview,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CommunityField(
                          key: const ValueKey('community-city'),
                          controller: _cityController,
                          label: 'Ciudad (opcional)',
                          hint: 'Palermo, Rosario, Córdoba...',
                          prefixIcon: Icons.location_city_outlined,
                          onChanged: _refreshPreview,
                        ),
                        const SizedBox(height: 20),
                        const _CommunityFormSection(
                          icon: Icons.favorite_border_rounded,
                          title: 'Fandom',
                          subtitle:
                              'Indicá el grupo o el tipo de comunidad principal.',
                        ),
                        const SizedBox(height: 10),
                        _CommunityField(
                          key: const ValueKey('community-fandom'),
                          controller: _fandomController,
                          label: 'Fandom o grupo principal',
                          hint: 'BTS, Stray Kids, multi fandom...',
                          prefixIcon: Icons.search_rounded,
                        ),
                        const SizedBox(height: 20),
                        const _CommunityFormSection(
                          icon: Icons.edit_note_rounded,
                          title: 'Descripción',
                          subtitle: 'Contá qué van a organizar o compartir.',
                        ),
                        const SizedBox(height: 10),
                        _CommunityField(
                          key: const ValueKey('community-description'),
                          controller: _descriptionController,
                          label: 'Descripción',
                          hint: 'Meetups, intercambios, charlas...',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 3,
                          maxLength: 200,
                        ),
                        const SizedBox(height: 20),
                        const _CommunityFormSection(
                          icon: Icons.lock_outline_rounded,
                          title: 'Privacidad',
                          subtitle:
                              'Las comunidades del acceso anticipado son públicas.',
                        ),
                        const SizedBox(height: 10),
                        _CommunityPrivacyCard(privacy: _privacy),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    12 + media.padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1020).withValues(alpha: 0.98),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: FilledButton.icon(
                    key: const ValueKey('community-create-submit'),
                    onPressed: _creating ? null : _create,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppTheme.rose,
                      disabledBackgroundColor: AppTheme.rose.withValues(
                        alpha: 0.36,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    icon: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.forum_outlined),
                    label: Text(_creating ? 'Creando...' : 'Crear comunidad'),
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

class _StudioSuggestionFormSheet extends StatelessWidget {
  const _StudioSuggestionFormSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * .94,
        child: Material(
          color: const Color(0xFF050710),
          child: Stack(
            children: [
              const Positioned.fill(
                bottom: null,
                child: SizedBox(
                  height: 190,
                  child: CustomPaint(painter: _StudioSuggestionHeroPainter()),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: IconButton.filledTonal(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Positioned.fill(
                top: 122,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF080B14),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: const Color(0xFF101522),
                        labelStyle: const TextStyle(color: AppTheme.cyan),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: .42),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.cyan,
                            width: 1.4,
                          ),
                        ),
                      ),
                      filledButtonTheme: FilledButtonThemeData(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: AppTheme.rose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.violet, AppTheme.rose],
                                  ),
                                ),
                                child: Icon(icon, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .64,
                                        ),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(child: _StudioProgress(active: true)),
                              SizedBox(width: 6),
                              Expanded(child: _StudioProgress(active: false)),
                              SizedBox(width: 6),
                              Expanded(child: _StudioProgress(active: false)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PASO 1 DE 3  ·  DATOS PRINCIPALES',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .5),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioProgress extends StatelessWidget {
  const _StudioProgress({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppTheme.rose : Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _StudioSuggestionHeroPainter extends CustomPainter {
  const _StudioSuggestionHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF31104B), Color(0xFF071827)],
        ).createShader(rect),
    );
    for (var index = 0; index < 5; index++) {
      final x = size.width * (.1 + index * .2);
      canvas.drawLine(
        Offset(x, 0),
        Offset(size.width * .5, size.height),
        Paint()
          ..color = (index.isEven ? AppTheme.cyan : AppTheme.rose).withValues(
            alpha: .22,
          )
          ..strokeWidth = 1.4,
      );
    }
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .34),
      42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppTheme.violet.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CommunityFormProgress extends StatelessWidget {
  const _CommunityFormProgress();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Datos de la comunidad',
      child: Row(
        children: [
          for (var index = 0; index < 3; index++) ...[
            Container(
              width: index == 0 ? 28 : 18,
              height: 4,
              decoration: BoxDecoration(
                color: index == 0
                    ? AppTheme.rose
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            if (index < 2) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _CommunityComposerPreview extends StatelessWidget {
  const _CommunityComposerPreview({
    required this.name,
    required this.location,
    required this.visual,
  });

  final String name;
  final String location;
  final _CommunityVisualTheme visual;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CommunityPlaceBackdrop(visual: visual),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: visual.highlight.withValues(alpha: 0.58),
                      ),
                    ),
                    child: const Text(
                      'VISTA PREVIA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CommunityLocationBadge(
                    label: location,
                    visual: visual,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFormSection extends StatelessWidget {
  const _CommunityFormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.rose, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityPrivacyCard extends StatelessWidget {
  const _CommunityPrivacyCard({required this.privacy});

  final String privacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('community-privacy'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.rose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.public_rounded, color: AppTheme.rose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  privacy,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cualquier fan puede encontrarla y solicitar unirse.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppTheme.rose),
        ],
      ),
    );
  }
}

class _CommunityField extends StatelessWidget {
  const _CommunityField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: AppTheme.cyan, size: 19),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.32),
          fontWeight: FontWeight.w600,
        ),
        counterStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.38),
          fontSize: 10,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.045),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.rose, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item, required this.onTap});

  final DiscoverEvent item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ImageListCard(
      imageAsset: item.imageAsset,
      eyebrow: '${item.city} · ${item.date}',
      title: item.title,
      subtitle: '${item.fandom} · ${item.location}',
      badge: 'Asistir',
      accent: AppTheme.teal,
      onTap: onTap,
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.item, required this.onTap});

  final DiscoverGuide item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      icon: Icons.auto_stories_outlined,
      eyebrow: item.category,
      title: item.title,
      subtitle: item.summary,
      accent: AppTheme.amber,
      badge: 'Guardar',
      onTap: onTap,
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.item, required this.onTap});

  final DiscoverStore item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ImageListCard(
      imageAsset: item.imageAsset,
      eyebrow: '${item.city} · ★ ${item.rating}',
      title: item.name,
      subtitle: item.category,
      badge: item.verified ? 'Verificada' : 'Demo',
      accent: AppTheme.indigo,
      onTap: onTap,
    );
  }
}

class _ImageListCard extends StatelessWidget {
  const _ImageListCard({
    super.key,
    required this.imageAsset,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accent,
    required this.onTap,
    this.visual,
  });

  final String imageAsset;
  final Widget? visual;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String badge;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 88,
                height: 96,
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
                            AppTheme.night.withValues(alpha: 0.64),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 7,
                      child: _SmallGlassBadge(label: badge, color: accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow, style: _eyebrowStyle, maxLines: 1),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: _compactTitleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right, color: accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallGlassBadge extends StatelessWidget {
  const _SmallGlassBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        label,
        style: _smallBadgeStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PlainListCard extends StatelessWidget {
  const _PlainListCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accent;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.24),
                    AppTheme.violet.withValues(alpha: 0.16),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(eyebrow, style: _eyebrowStyle)),
                      const SizedBox(width: 8),
                      _SmallGlassBadge(label: badge, color: accent),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: _compactTitleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: _mutedStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: accent),
          ],
        ),
      ),
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text('$label · $count', style: _eyebrowStyle),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = '',
    this.color = AppTheme.cyan,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _PressableScale(
        onTap: onTap,
        borderRadius: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.nightSoft.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      AppTheme.rose.withValues(alpha: 0.14),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _compactTitleStyle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: _mutedStyle, maxLines: 2),
                    if (badge.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _SmallGlassBadge(label: badge, color: color),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.rose),
            ],
          ),
        ),
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
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.cyan, AppTheme.rose],
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: _sectionTitleStyle)),
        Text(trailing, style: _eyebrowStyle),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    super.key,
    required this.text,
    this.title,
    this.actionLabel,
    this.onAction,
    this.mascotAsset = 'assets/brand/hally_mascot_wave_transparent.png',
    this.icon = Icons.auto_awesome_rounded,
    this.accent = AppTheme.cyan,
  });

  final String text;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String mascotAsset;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.nightSoft.withValues(alpha: 0.9),
            accent.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 92,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      accent.withValues(alpha: 0.14),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(mascotAsset, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [accent, AppTheme.rose]),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: _compactTitleStyle),
                  const SizedBox(height: 5),
                ],
                Text(text, style: _mutedStyle),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BetaSoonSheet extends StatelessWidget {
  const _BetaSoonSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.violet.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.rose, AppTheme.cyan],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: _compactTitleStyle)),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: _mutedStyle),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BetaCommunityDetailView extends StatefulWidget {
  const _BetaCommunityDetailView({
    required this.community,
    required this.initiallyJoined,
    required this.followService,
    required this.safetyService,
    required this.onOpenProfile,
    required this.onMembershipChanged,
  });

  final DiscoverCommunity community;
  final bool initiallyJoined;
  final LocalFollowService followService;
  final LocalSafetyService safetyService;
  final ValueChanged<CommunityProfile> onOpenProfile;
  final Future<void> Function() onMembershipChanged;

  @override
  State<_BetaCommunityDetailView> createState() =>
      _BetaCommunityDetailViewState();
}

class _BetaCommunityDetailViewState extends State<_BetaCommunityDetailView> {
  final _controller = TextEditingController();
  final _messageScrollController = ScrollController();
  final _messages = <_CommunityMessage>[];
  final _authorsById = <String, CommunityProfile>{};
  bool _joined = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _sending = false;
  int _restoreEpoch = 0;

  @override
  void initState() {
    super.initState();
    _joined = widget.initiallyJoined;
    _restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final epoch = ++_restoreEpoch;
    if (!_joined) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final rows = await supabase.Supabase.instance.client
          .from('community_messages')
          .select('id,sender_id,body,created_at')
          .eq('community_id', widget.community.id)
          .order('created_at', ascending: true)
          .limit(80);
      if (!mounted) return;
      final messages = rows
          .cast<Map<String, dynamic>>()
          .map(_CommunityMessage.fromRow)
          .toList(growable: false);
      final senderIds = messages
          .map((message) => message.senderId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      var authors = <CommunityProfile>[];
      try {
        authors = await widget.followService.restoreProfilesByIds(senderIds);
      } catch (error) {
        debugPrint('DISCOVER_COMMUNITY_AUTHORS_ERROR $error');
      }
      if (!mounted || epoch != _restoreEpoch) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _authorsById
          ..clear()
          ..addEntries(authors.map((profile) => MapEntry(profile.id, profile)));
        _loading = false;
      });
      _scrollToLatest();
    } catch (error) {
      debugPrint('DISCOVER_COMMUNITY_MESSAGES_ERROR $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _join() async {
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;
    try {
      await client.from('community_members').upsert({
        'community_id': widget.community.id,
        'user_id': authUser.id,
        'role': 'member',
      }, onConflict: 'community_id,user_id');
      if (!mounted) return;
      setState(() {
        _joined = true;
        _loading = true;
      });
      await widget.onMembershipChanged();
      await _restore();
    } catch (error) {
      debugPrint('DISCOVER_COMMUNITY_JOIN_ERROR $error');
      _showLocalSnack('No pudimos unirte a la comunidad.');
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;
    setState(() => _sending = true);
    try {
      await client.from('community_messages').insert({
        'community_id': widget.community.id,
        'sender_id': authUser.id,
        'body': body,
      });
      _controller.clear();
      await _restore();
    } catch (error) {
      debugPrint('DISCOVER_COMMUNITY_SEND_ERROR $error');
      _showLocalSnack('No pudimos enviar el mensaje.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showLocalSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _reportCommunity() async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      contentType: 'community',
      contentId: widget.community.id,
      reportedUserId: widget.community.createdBy,
      title: 'Reportar comunidad',
    );
    if (sent) _showLocalSnack('Gracias. Recibimos tu reporte.');
  }

  Future<void> _reportMessage(_CommunityMessage message) async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      contentType: 'community_message',
      contentId: message.id,
      reportedUserId: message.senderId,
      title: 'Reportar mensaje',
      metadata: {'community_id': widget.community.id},
    );
    if (sent) _showLocalSnack('Gracias. Recibimos tu reporte.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HallyFeatureTip(
          featureId: 'community_chat_intro',
          title: 'Este chat es de todos 💬',
          message: 'Tocá un nombre o avatar para visitar ese perfil.',
          mascotAsset: 'assets/brand/hally_mascot_community.png',
        ),
        _communityHeader(),
        const SizedBox(height: 8),
        Expanded(child: _messageList()),
        if (_joined) _composer(),
      ],
    );
  }

  Widget _communityHeader() {
    return _NeonFrame(
      radius: 18,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [AppTheme.violet, AppTheme.cyan],
                ),
              ),
              child: const Icon(Icons.forum_rounded, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.community.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.community.members} miembros · ${widget.community.fandom}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _miniMutedStyle,
                  ),
                ],
              ),
            ),
            if (!_joined)
              FilledButton(onPressed: _join, child: const Text('Unirme')),
            IconButton(
              key: const ValueKey('community-report'),
              onPressed: _reportCommunity,
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Reportar comunidad',
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList() {
    if (!_joined) {
      return const Center(
        child: _EmptyPanel(
          text: 'Unite a esta comunidad para ver y enviar mensajes.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: _EmptyPanel(
          text:
              'No pudimos cargar los mensajes. Revisá tu conexión y reintentá.',
          actionLabel: 'Reintentar',
          onAction: _restore,
          icon: Icons.wifi_off_rounded,
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: _EmptyPanel(
          text: 'Todavía no hay mensajes. Sé la primera persona en saludar.',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      );
    }

    final currentUserId =
        supabase.Supabase.instance.client.auth.currentUser?.id;
    return ListView.builder(
      controller: _messageScrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return CommunityChatMessageTile(
          key: ValueKey('community-message-${message.id}'),
          profile: _authorsById[message.senderId],
          body: message.body,
          timeLabel: message.clockLabel,
          isCurrentUser: message.senderId == currentUserId,
          onOpenProfile: widget.onOpenProfile,
          onReport: message.senderId == currentUserId
              ? null
              : () => _reportMessage(message),
        );
      },
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Enviar un mensaje...',
                  filled: true,
                  fillColor: const Color(0xFF101831),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: AppTheme.cyan.withValues(alpha: .24),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: AppTheme.cyan.withValues(alpha: .24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar mensaje',
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.rose,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _FanEventCard extends StatelessWidget {
  const _FanEventCard({
    required this.event,
    required this.attending,
    required this.onAttend,
  });

  final _FanEvent event;
  final bool attending;
  final VoidCallback onAttend;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      icon: Icons.event_outlined,
      eyebrow: '${event.city}, ${event.country} · ${event.dateLabel}',
      title: event.title,
      subtitle: '${event.fandomLabel} · ${event.place}',
      accent: AppTheme.teal,
      badge: attending ? 'Me interesa' : 'Asistir',
      onTap: onAttend,
    );
  }
}

class _KpopGuideInfoCard extends StatelessWidget {
  const _KpopGuideInfoCard({required this.guide});

  final _KpopGuideInfo guide;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      icon: guide.icon,
      eyebrow: 'Guía base',
      title: guide.title,
      subtitle: guide.description,
      accent: AppTheme.amber,
      badge: 'Leer',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _BetaSoonSheet(title: guide.title, message: guide.longDescription),
      ),
    );
  }
}

class _KpopQuestionCard extends StatelessWidget {
  const _KpopQuestionCard({required this.question, required this.onTap});

  final _KpopQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      icon: Icons.question_answer_outlined,
      eyebrow: question.createdLabel,
      title: question.title,
      subtitle: question.detail.isEmpty ? 'Pregunta abierta' : question.detail,
      accent: AppTheme.rose,
      badge: 'Responder',
      onTap: onTap,
    );
  }
}

class _KpopQuestionDetailView extends StatefulWidget {
  const _KpopQuestionDetailView({required this.question});

  final _KpopQuestion question;

  @override
  State<_KpopQuestionDetailView> createState() =>
      _KpopQuestionDetailViewState();
}

class _KpopQuestionDetailViewState extends State<_KpopQuestionDetailView> {
  final _controller = TextEditingController();
  final _answers = <_KpopAnswer>[];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final rows = await supabase.Supabase.instance.client
          .from('kpop101_answers')
          .select('id,body,author_id,created_at')
          .eq('question_id', widget.question.id)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _answers
          ..clear()
          ..addAll(rows.cast<Map<String, dynamic>>().map(_KpopAnswer.fromRow));
        _loading = false;
      });
    } catch (error) {
      debugPrint('DISCOVER_KPOP101_ANSWERS_ERROR $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    final client = supabase.Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;
    setState(() => _sending = true);
    try {
      await client.from('kpop101_answers').insert({
        'question_id': widget.question.id,
        'author_id': authUser.id,
        'body': body,
      });
      _controller.clear();
      await _restore();
    } catch (error) {
      debugPrint('DISCOVER_KPOP101_ANSWER_SEND_ERROR $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos publicar la respuesta.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NeonFrame(
          radius: 22,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.nightSoft.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.question.title, style: _detailTitleStyle),
                if (widget.question.detail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(widget.question.detail, style: _mutedStyle),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle(title: 'Respuestas', trailing: 'Fans'),
        const SizedBox(height: 10),
        if (_loading)
          const _EmptyPanel(text: 'Cargando respuestas...')
        else if (_answers.isEmpty)
          const _EmptyPanel(
            text: 'Todavía no hay respuestas. Sé la primera persona en ayudar.',
          )
        else
          ..._answers.map(
            (answer) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlainListCard(
                icon: Icons.forum_outlined,
                eyebrow: answer.createdLabel,
                title: answer.body,
                subtitle: 'Respuesta de fan',
                accent: AppTheme.violet,
                badge: '101',
                onTap: () {},
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CommunityField(
                controller: _controller,
                label: 'Responder',
                hint: 'Escribí una respuesta clara...',
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _FanEventComposerSheet extends StatefulWidget {
  const _FanEventComposerSheet({required this.onSubmit});

  final Future<void> Function(_FanEventDraft event) onSubmit;

  @override
  State<_FanEventComposerSheet> createState() => _FanEventComposerSheetState();
}

class _FanEventComposerSheetState extends State<_FanEventComposerSheet> {
  final _title = TextEditingController();
  final _fandom = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Argentina');
  final _place = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _description = TextEditingController();
  final _contact = TextEditingController();
  final _link = TextEditingController();
  String _category = 'random play dance';
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _fandom,
      _city,
      _country,
      _place,
      _date,
      _time,
      _description,
      _contact,
      _link,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime? _parseStartsAt() {
    final dateParts = _date.text.trim().split('/');
    final timeParts = _time.text.trim().split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return null;
    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if ([day, month, year, hour, minute].any((value) => value == null)) {
      return null;
    }
    return DateTime(year!, month!, day!, hour!, minute!);
  }

  Future<void> _submit() async {
    final startsAt = _parseStartsAt();
    if (_title.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _country.text.trim().isEmpty ||
        _place.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        startsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completá título, ciudad, país, lugar, fecha y descripción.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        _FanEventDraft(
          title: _title.text.trim(),
          fandom: _fandom.text.trim(),
          city: _city.text.trim(),
          country: _country.text.trim(),
          place: _place.text.trim(),
          startsAt: startsAt,
          description: _description.text.trim(),
          organizerContact: _contact.text.trim(),
          externalLink: _link.text.trim(),
          category: _category,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('DISCOVER_EVENT_CREATE_ERROR $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos publicar el evento.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DiscoverFormSheet(
      title: 'Proponer evento',
      subtitle:
          'Publicá actividades reales de comunidad, sin eventos inventados.',
      children: [
        _CommunityField(
          controller: _title,
          label: 'Título',
          hint: 'Random play dance',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CommunityField(
                controller: _city,
                label: 'Ciudad',
                hint: 'CABA',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CommunityField(
                controller: _country,
                label: 'País',
                hint: 'Argentina',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _place,
          label: 'Lugar aproximado',
          hint: 'Parque, shopping, sala...',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CommunityField(
                controller: _date,
                label: 'Fecha',
                hint: '25/06/2026',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CommunityField(
                controller: _time,
                label: 'Hora',
                hint: '18:00',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _fandom,
          label: 'Fandom opcional',
          hint: 'Multi fandom, BTS...',
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _category,
          dropdownColor: AppTheme.nightSoft,
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: const [
            DropdownMenuItem(
              value: 'random play dance',
              child: Text('Random play dance'),
            ),
            DropdownMenuItem(value: 'cupsleeve', child: Text('Cupsleeve')),
            DropdownMenuItem(value: 'fanmeeting', child: Text('Fanmeeting')),
            DropdownMenuItem(value: 'trade meet', child: Text('Trade meet')),
            DropdownMenuItem(value: 'other', child: Text('Otro')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _description,
          label: 'Descripción',
          hint: 'Contá de qué se trata...',
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _contact,
          label: 'Organizador/contacto opcional',
          hint: '@cuenta o contacto',
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _link,
          label: 'Link externo opcional',
          hint: 'Instagram, formulario...',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.event_available_outlined),
          label: Text(_saving ? 'Publicando...' : 'Publicar evento'),
        ),
      ],
    );
  }
}

class _KpopQuestionComposerSheet extends StatefulWidget {
  const _KpopQuestionComposerSheet({required this.onSubmit});

  final Future<void> Function(String title, String detail) onSubmit;

  @override
  State<_KpopQuestionComposerSheet> createState() =>
      _KpopQuestionComposerSheetState();
}

class _KpopQuestionComposerSheetState
    extends State<_KpopQuestionComposerSheet> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(title, _detail.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('DISCOVER_KPOP101_QUESTION_CREATE_ERROR $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos publicar la pregunta.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DiscoverFormSheet(
      title: 'Hacer pregunta',
      subtitle: 'Preguntá algo real para que otros fans puedan responder.',
      children: [
        _CommunityField(
          controller: _title,
          label: 'Pregunta',
          hint: '¿Qué significa bias?',
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _detail,
          label: 'Detalle opcional',
          hint: 'Agregá contexto si hace falta...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.question_answer_outlined),
          label: Text(_saving ? 'Publicando...' : 'Publicar pregunta'),
        ),
      ],
    );
  }
}

class _ShopSuggestionSheet extends StatefulWidget {
  const _ShopSuggestionSheet({required this.onSubmit});

  final Future<void> Function(_ShopSuggestionDraft draft) onSubmit;

  @override
  State<_ShopSuggestionSheet> createState() => _ShopSuggestionSheetState();
}

class _ShopSuggestionSheetState extends State<_ShopSuggestionSheet> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Argentina');
  final _contact = TextEditingController();
  final _description = TextEditingController();
  String _type = 'photocards';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _country.dispose();
    _contact.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _country.text.trim().isEmpty ||
        _contact.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá nombre, ciudad, país y contacto.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        _ShopSuggestionDraft(
          name: _name.text.trim(),
          city: _city.text.trim(),
          country: _country.text.trim(),
          contact: _contact.text.trim(),
          type: _type,
          description: _description.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('DISCOVER_SHOP_SUGGESTION_ERROR $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos guardar la sugerencia.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DiscoverFormSheet(
      title: 'Sugerir tienda',
      subtitle:
          'La sugerencia queda pendiente de revisión. Sin pagos ni marketplace todavía.',
      children: [
        _CommunityField(
          controller: _name,
          label: 'Nombre',
          hint: 'Nombre de tienda',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CommunityField(
                controller: _city,
                label: 'Ciudad',
                hint: 'CABA',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CommunityField(
                controller: _country,
                label: 'País',
                hint: 'Argentina',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _contact,
          label: 'Instagram/web/contacto',
          hint: '@tienda o https://...',
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _type,
          dropdownColor: AppTheme.nightSoft,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: const [
            DropdownMenuItem(value: 'albums', child: Text('Álbumes')),
            DropdownMenuItem(value: 'photocards', child: Text('Photocards')),
            DropdownMenuItem(value: 'merch', child: Text('Merch')),
            DropdownMenuItem(value: 'lightsticks', child: Text('Lightsticks')),
            DropdownMenuItem(value: 'handmade', child: Text('Handmade')),
            DropdownMenuItem(value: 'other', child: Text('Otro')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _type = value);
          },
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _description,
          label: 'Descripción',
          hint: 'Qué vende o por qué sugerís esta tienda...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.storefront_outlined),
          label: Text(_saving ? 'Enviando...' : 'Enviar sugerencia'),
        ),
      ],
    );
  }
}

class _KpopEntitySuggestionSheet extends StatefulWidget {
  const _KpopEntitySuggestionSheet({
    required this.artistTagService,
    required this.onOpenExisting,
    required this.onSubmit,
  });

  final LocalArtistTagService artistTagService;
  final ValueChanged<KpopEntity> onOpenExisting;
  final Future<void> Function(ArtistSuggestionDraft draft) onSubmit;

  @override
  State<_KpopEntitySuggestionSheet> createState() =>
      _KpopEntitySuggestionSheetState();
}

class _KpopEntitySuggestionSheetState
    extends State<_KpopEntitySuggestionSheet> {
  final _name = TextEditingController();
  final _fandom = TextEditingController();
  final _country = TextEditingController();
  final _agency = TextEditingController();
  final _officialUrl = TextEditingController();
  final _note = TextEditingController();
  final _matches = <KpopEntity>[];
  Timer? _matchDebounce;
  int _matchEpoch = 0;
  KpopEntitySuggestionType _type = KpopEntitySuggestionType.group;
  bool _saving = false;
  bool _checkingMatches = false;
  bool _matchLookupFailed = false;

  @override
  void dispose() {
    _matchDebounce?.cancel();
    _name.dispose();
    _fandom.dispose();
    _country.dispose();
    _agency.dispose();
    _officialUrl.dispose();
    _note.dispose();
    super.dispose();
  }

  void _scheduleMatchLookup(String query) {
    _matchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _matches.clear();
        _checkingMatches = false;
        _matchLookupFailed = false;
      });
      return;
    }
    setState(() {
      _checkingMatches = true;
      _matchLookupFailed = false;
    });
    _matchDebounce = Timer(const Duration(milliseconds: 300), () {
      _lookupMatches(query);
    });
  }

  Future<bool> _lookupMatches(String query) async {
    final epoch = ++_matchEpoch;
    try {
      final results = await widget.artistTagService.searchEntities(
        query: query,
        limit: 8,
      );
      if (!mounted || epoch != _matchEpoch) return false;
      setState(() {
        _matches
          ..clear()
          ..addAll(results);
        _checkingMatches = false;
        _matchLookupFailed = false;
      });
      return true;
    } catch (error) {
      debugPrint('DISCOVER_ENTITY_DUPLICATE_LOOKUP_ERROR $error');
      if (!mounted || epoch != _matchEpoch) return false;
      setState(() {
        _matches.clear();
        _checkingMatches = false;
        _matchLookupFailed = true;
      });
      return false;
    }
  }

  bool _isExactDuplicate(KpopEntity entity, String name) {
    return isExactKpopEntityDuplicate(
      entity: entity,
      requestedName: name,
      requestedType: _type.catalogType,
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      _matchDebounce?.cancel();
      final lookupSucceeded = await _lookupMatches(name);
      if (!lookupSucceeded || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No pudimos comprobar coincidencias. Probá de nuevo.',
              ),
            ),
          );
        }
        return;
      }
      if (_matches.any((entity) => _isExactDuplicate(entity, name))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya existe una coincidencia exacta. Abrí esa ficha en lugar de duplicarla.',
            ),
          ),
        );
        return;
      }
      await widget.onSubmit(
        ArtistSuggestionDraft(
          name: name,
          type: _type,
          fandom: _fandom.text,
          country: _country.text,
          agency: _agency.text,
          officialUrl: _officialUrl.text,
          note: _note.text,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('DISCOVER_ENTITY_SUGGESTION_REAL_ERROR $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos enviar la sugerencia.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DiscoverFormSheet(
      title: 'Agregar grupo o artista',
      subtitle:
          'La solicitud queda pendiente de revisión; no crea ni publica una ficha automáticamente.',
      children: [
        _CommunityField(
          key: const ValueKey('discover-real-suggestion-name'),
          controller: _name,
          label: 'Nombre',
          hint: 'Nombre del grupo o artista/solista',
          onChanged: _scheduleMatchLookup,
        ),
        if (_checkingMatches)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_matchLookupFailed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No se pudieron verificar posibles duplicados.'),
          )
        else if (_matches.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Encontramos coincidencias. ¿Querías abrir una de estas fichas?',
            ),
          ),
          for (final entity in _matches)
            ListTile(
              key: ValueKey('entity-suggestion-match-${entity.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entity.type == KpopEntityType.group
                    ? Icons.groups_2_outlined
                    : Icons.person_search_outlined,
                color: AppTheme.cyan,
              ),
              title: Text(entity.name),
              subtitle: Text(entity.typeLabel),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => widget.onOpenExisting(entity),
            ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<KpopEntitySuggestionType>(
          initialValue: _type,
          dropdownColor: AppTheme.nightSoft,
          decoration: const InputDecoration(labelText: '¿Qué querés agregar?'),
          items: const [
            DropdownMenuItem(
              value: KpopEntitySuggestionType.group,
              child: Text('Grupo'),
            ),
            DropdownMenuItem(
              value: KpopEntitySuggestionType.artist,
              child: Text('Artista / Solista'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _type = value);
          },
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _fandom,
          label: 'Fandom si lo sabés',
          hint: 'Ej: ARMY, BLINK, STAY',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CommunityField(
                controller: _country,
                label: 'País si lo sabés',
                hint: 'Corea, Japón, Argentina...',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CommunityField(
                controller: _agency,
                label: 'Agencia',
                hint: 'Opcional',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _officialUrl,
          label: 'Red o link oficial',
          hint: 'Opcional',
        ),
        const SizedBox(height: 10),
        _CommunityField(
          controller: _note,
          label: 'Descripción opcional',
          hint: 'Contanos brevemente quién es o por qué sumarlo...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.send_rounded),
          label: Text(_saving ? 'Enviando...' : 'Enviar sugerencia'),
        ),
      ],
    );
  }
}

class _DiscoverFormSheet extends StatelessWidget {
  const _DiscoverFormSheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final useStudioLayout =
        title == 'Sugerir tienda' || title == 'Agregar grupo o artista';
    final icon = switch (title) {
      'Proponer evento' => Icons.event_available_outlined,
      'Pregunta K-pop 101' => Icons.school_outlined,
      'Sugerir tienda' => Icons.storefront_outlined,
      _ => Icons.auto_awesome_outlined,
    };
    final visual = switch (title) {
      'Proponer evento' => PremiumFormVisual.event,
      'Pregunta K-pop 101' => PremiumFormVisual.create,
      'Sugerir tienda' => PremiumFormVisual.store,
      _ => PremiumFormVisual.community,
    };

    if (useStudioLayout) {
      return _StudioSuggestionFormSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        children: children,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.92,
        child: PremiumFormShell(
          title: title,
          subtitle: subtitle,
          icon: icon,
          visual: visual,
          trailing: IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          child: PremiumFormSection(
            title: 'Completá los datos',
            subtitle: 'Podés revisar todo antes de enviarlo.',
            icon: Icons.edit_note_rounded,
            accent: visual == PremiumFormVisual.event
                ? AppTheme.rose
                : AppTheme.cyan,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1221),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionSheet extends StatefulWidget {
  const _SuggestionSheet({required this.onSubmit});

  final ValueChanged<DiscoverArtistEntity> onSubmit;

  @override
  State<_SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends State<_SuggestionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  DiscoverEntityType _type = DiscoverEntityType.idolGroup;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppTheme.night.withValues(alpha: 0.38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.cyan),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final country = _countryController.text.trim();
    final region = _regionController.text.trim();
    final description = _descriptionController.text.trim();
    final reference = _referenceController.text.trim();
    final entity = DiscoverArtistEntity(
      groupId:
          'suggestion-${DateTime.now().millisecondsSinceEpoch}-${_slug(name)}',
      name: name,
      aliases: const [],
      country: country,
      region: region.isEmpty ? country : region,
      type: _type,
      status: DiscoverEntityStatus.pendingReview,
      fandom: 'Por revisar',
      description: description,
      members: const ['Pendiente de revisión'],
      relatedNewsIds: const [],
      relatedFancamIds: const [],
      tags: [
        country,
        if (region.isNotEmpty) region,
        _type.label,
        if (reference.isNotEmpty) reference,
      ],
      source: 'community_suggestions',
      createdBy: 'usuario_beta',
      lastUpdated: '2026-06-04',
      imageAsset: 'assets/demo-posts/post-05.jpg',
      referenceUrl: reference,
    );
    widget.onSubmit(entity);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Agregar grupo o artista',
                    style: _detailTitleStyle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'La sugerencia queda pendiente para moderación y luego podría sincronizarse con Supabase.',
                    style: _mutedStyle,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('discover-suggestion-name'),
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                      'Nombre del grupo/artista',
                      Icons.badge_outlined,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Escribí un nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('discover-suggestion-country'),
                          controller: _countryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('País', Icons.flag_outlined),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'País';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('discover-suggestion-region'),
                          controller: _regionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration(
                            'Región / ciudad',
                            Icons.place_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DiscoverEntityType>(
                    initialValue: _type,
                    dropdownColor: AppTheme.nightSoft,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: _decoration('Tipo', Icons.category_outlined),
                    items: [
                      for (final type in DiscoverEntityType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('discover-suggestion-description'),
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    minLines: 3,
                    maxLines: 4,
                    decoration: _decoration(
                      'Descripción',
                      Icons.notes_outlined,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Sumá una descripción corta';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('discover-suggestion-reference'),
                    controller: _referenceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                      'Link o referencia opcional',
                      Icons.link_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const ValueKey('discover-submit-suggestion'),
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Enviar sugerencia'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FanEvent {
  const _FanEvent({
    required this.id,
    required this.title,
    required this.fandom,
    required this.country,
    required this.city,
    required this.place,
    required this.startsAt,
    required this.description,
    required this.category,
  });

  final String id;
  final String title;
  final String fandom;
  final String country;
  final String city;
  final String place;
  final DateTime? startsAt;
  final String description;
  final String category;

  factory _FanEvent.fromRow(Map<String, dynamic> row) {
    return _FanEvent(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? 'Evento HallyuHub',
      fandom: row['fandom'] as String? ?? '',
      country: row['country'] as String? ?? '',
      city: row['city'] as String? ?? '',
      place: row['place'] as String? ?? '',
      startsAt: DateTime.tryParse(row['starts_at'] as String? ?? ''),
      description: row['description'] as String? ?? '',
      category: row['category'] as String? ?? 'other',
    );
  }

  String get fandomLabel => fandom.isEmpty ? 'Multi fandom' : fandom;

  String get dateLabel {
    final value = startsAt;
    if (value == null) return 'Fecha a confirmar';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _FanEventDraft {
  const _FanEventDraft({
    required this.title,
    required this.fandom,
    required this.city,
    required this.country,
    required this.place,
    required this.startsAt,
    required this.description,
    required this.organizerContact,
    required this.externalLink,
    required this.category,
  });

  final String title;
  final String fandom;
  final String city;
  final String country;
  final String place;
  final DateTime startsAt;
  final String description;
  final String organizerContact;
  final String externalLink;
  final String category;
}

class _KpopQuestion {
  const _KpopQuestion({
    required this.id,
    required this.title,
    required this.detail,
    required this.authorId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String detail;
  final String authorId;
  final DateTime? createdAt;

  factory _KpopQuestion.fromRow(Map<String, dynamic> row) {
    return _KpopQuestion(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? 'Pregunta K-pop',
      detail: row['detail'] as String? ?? '',
      authorId: row['author_id'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  String get createdLabel {
    final value = createdAt;
    if (value == null) return 'Pregunta abierta';
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} d';
  }
}

class _KpopAnswer {
  const _KpopAnswer({
    required this.id,
    required this.body,
    required this.authorId,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String authorId;
  final DateTime? createdAt;

  factory _KpopAnswer.fromRow(Map<String, dynamic> row) {
    return _KpopAnswer(
      id: row['id'] as String? ?? '',
      body: row['body'] as String? ?? '',
      authorId: row['author_id'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  String get createdLabel {
    final value = createdAt;
    if (value == null) return 'Respuesta';
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} d';
  }
}

class _CommunityMessage {
  const _CommunityMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime? createdAt;

  factory _CommunityMessage.fromRow(Map<String, dynamic> row) {
    return _CommunityMessage(
      id: row['id'] as String? ?? '',
      senderId: row['sender_id'] as String? ?? '',
      body: row['body'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  String get clockLabel {
    final value = createdAt;
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ShopSuggestionDraft {
  const _ShopSuggestionDraft({
    required this.name,
    required this.city,
    required this.country,
    required this.contact,
    required this.type,
    required this.description,
  });

  final String name;
  final String city;
  final String country;
  final String contact;
  final String type;
  final String description;
}

class _KpopGuideInfo {
  const _KpopGuideInfo({
    required this.title,
    required this.description,
    required this.longDescription,
    required this.icon,
  });

  final String title;
  final String description;
  final String longDescription;
  final IconData icon;
}

const _kpopGuideInfos = [
  _KpopGuideInfo(
    title: '¿Qué es un bias?',
    description:
        'Tu integrante favorito o con quien más conectás dentro de un grupo.',
    longDescription:
        'En fandom K-pop, bias es la persona del grupo que más te gusta o seguís de cerca. Puede cambiar con el tiempo y no tiene que ser una sola.',
    icon: Icons.favorite_border,
  ),
  _KpopGuideInfo(
    title: '¿Qué es un comeback?',
    description:
        'El regreso de un grupo o artista con música, concepto y promoción nueva.',
    longDescription:
        'Un comeback suele incluir canción principal, teaser, concepto visual, promociones y presentaciones. No significa que el artista estuviera retirado.',
    icon: Icons.auto_awesome_outlined,
  ),
  _KpopGuideInfo(
    title: '¿Qué es una fancam?',
    description:
        'Video enfocado en una performance o en un integrante durante una presentación.',
    longDescription:
        'Las fancams ayudan a revivir escenarios, coreografías y momentos específicos. En HallyuHub queremos que siempre estén subidas por fans respetando reglas de contenido.',
    icon: Icons.videocam_outlined,
  ),
  _KpopGuideInfo(
    title: '¿Qué es una photocard?',
    description:
        'Tarjeta coleccionable que suele venir con álbumes o merch oficial.',
    longDescription:
        'Las photocards pueden coleccionarse, intercambiarse o venderse entre fans. Durante el acceso anticipado evitamos pagos reales y priorizamos contacto seguro.',
    icon: Icons.style_outlined,
  ),
  _KpopGuideInfo(
    title: '¿Qué es un lightstick?',
    description:
        'Luz oficial de un grupo o fandom usada en conciertos y eventos.',
    longDescription:
        'El lightstick identifica a un fandom y puede sincronizarse en conciertos. También se usa como símbolo de comunidad.',
    icon: Icons.lightbulb_outline,
  ),
  _KpopGuideInfo(
    title: '¿Qué es un fan chant?',
    description:
        'Cantos coordinados de fans durante una canción o presentación.',
    longDescription:
        'Los fan chants suelen acompañar partes específicas de una canción y ayudan a crear energía colectiva en vivo.',
    icon: Icons.record_voice_over_outlined,
  ),
];

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

String _slug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

IconData _entityIcon(DiscoverEntityType type) {
  switch (type) {
    case DiscoverEntityType.idolGroup:
      return Icons.groups_2_outlined;
    case DiscoverEntityType.soloist:
      return Icons.mic_external_on_outlined;
    case DiscoverEntityType.rookie:
      return Icons.auto_awesome_outlined;
    case DiscoverEntityType.fanCrew:
      return Icons.diversity_3_outlined;
    case DiscoverEntityType.project:
      return Icons.public_outlined;
    case DiscoverEntityType.localKpop:
      return Icons.location_city_outlined;
    case DiscoverEntityType.coverCrew:
      return Icons.directions_run_outlined;
  }
}

Color _entityColor(DiscoverEntityStatus status) {
  switch (status) {
    case DiscoverEntityStatus.verified:
      return AppTheme.cyan;
    case DiscoverEntityStatus.emerging:
      return AppTheme.teal;
    case DiscoverEntityStatus.communitySuggested:
      return AppTheme.violet;
    case DiscoverEntityStatus.pendingReview:
      return AppTheme.amber;
  }
}

Color _kpopIdentityAccent(String name) {
  const accents = [
    AppTheme.cyan,
    AppTheme.rose,
    AppTheme.violet,
    AppTheme.indigo,
    AppTheme.teal,
  ];
  final seed = name.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return accents[seed % accents.length];
}

_KpopEmblemKind _kpopEmblemKind(String name) {
  switch (name.trim().toLowerCase()) {
    case 'bts':
      return _KpopEmblemKind.gates;
    case 'aespa':
      return _KpopEmblemKind.orbit;
    case 'ateez':
      return _KpopEmblemKind.prism;
    default:
      return _KpopEmblemKind.monogram;
  }
}

class _KpopEntityCounts {
  const _KpopEntityCounts({
    required this.groups,
    required this.artistsAndIdols,
    required this.total,
  });

  final int groups;
  final int artistsAndIdols;
  final int total;
}

String _kpopIdentityWordmark(String name) {
  final compact = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.isEmpty) return 'HALLYU';
  final key = compact.toLowerCase();
  const displayMarks = <String, String>{
    'blackpink': 'BLACK\nPINK',
    'stray kids': 'SKZ',
    'newjeans': 'New\nJeans',
    'le sserafim': 'LE\nSSERAFIM',
    'seventeen': 'SVT',
    'enhypen': 'EN—',
    'bang chan': 'BC',
    'jimin': 'J',
    'jennie': 'JN',
    'jungkook': 'JK',
    'lisa': 'L',
  };
  return displayMarks[key] ?? compact;
}

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
const _editorialTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 19,
  height: 1.12,
  fontWeight: FontWeight.w900,
);
const _railTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  height: 1.08,
  fontWeight: FontWeight.w900,
);
const _compactTitleStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w900,
);
const _pillTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.w900,
);
const _smallBadgeStyle = TextStyle(
  color: Colors.white,
  fontSize: 10,
  fontWeight: FontWeight.w900,
);
const _statValueStyle = TextStyle(
  color: Colors.white,
  fontSize: 19,
  fontWeight: FontWeight.w900,
);
final _mutedStyle = TextStyle(
  color: Colors.white.withValues(alpha: 0.67),
  height: 1.35,
  fontWeight: FontWeight.w600,
);
final _miniMutedStyle = TextStyle(
  color: Colors.white.withValues(alpha: 0.6),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w700,
);
const _eyebrowStyle = TextStyle(
  color: AppTheme.cyan,
  fontSize: 12,
  fontWeight: FontWeight.w900,
);
