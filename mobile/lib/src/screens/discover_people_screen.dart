import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_chat_service.dart';
import '../services/local_content_category_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/local_story_service.dart';
import '../services/local_user_tag_service.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hub_avatar.dart';
import 'public_profile_screen.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({
    super.key,
    this.currentUser,
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.chatService = const LocalChatService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
  });

  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalChatService chatService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _profiles = <CommunityProfile>[];
  final _followingIds = <String>{};
  final _busyFollowIds = <String>{};
  Timer? _debounce;
  String _query = '';
  String? _error;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    LocalFollowService.revision.addListener(_reloadAfterFollowChange);
    _loadProfiles();
  }

  @override
  void dispose() {
    LocalFollowService.revision.removeListener(_reloadAfterFollowChange);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _reloadAfterFollowChange() {
    if (!mounted || _busyFollowIds.isNotEmpty) return;
    _loadProfiles(showLoading: false);
  }

  void _onQueryChanged(String value) {
    _query = value.trim();
    _debounce?.cancel();
    setState(() {
      _error = null;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _loadProfiles);
  }

  Future<void> _loadProfiles({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.followService.restoreProfiles(query: _query, limit: 80),
        widget.followService.restoreFollowingIds(),
        widget.safetyService.restoreBlockedUserIds(),
      ]);
      if (!mounted || requestId != _requestId) return;
      final following = results[1] as Set<String>;
      final blocked = results[2] as Set<String>;
      final currentUsername =
          widget.currentUser?.username.trim().toLowerCase() ?? '';
      final profiles = (results[0] as List<CommunityProfile>)
          .where(
            (profile) =>
                profile.username.trim().toLowerCase() != currentUsername &&
                !blocked.contains(profile.id),
          )
          .toList(growable: false);
      setState(() {
        _profiles
          ..clear()
          ..addAll(profiles);
        _followingIds
          ..clear()
          ..addAll(following);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _profiles.clear();
        _loading = false;
        _error = 'No pudimos cargar las personas. Probá de nuevo.';
      });
      debugPrint('DISCOVER_PEOPLE_LOAD_ERROR error=$error');
    }
  }

  Future<void> _toggleFollow(CommunityProfile profile) async {
    if (_busyFollowIds.contains(profile.id)) return;
    final wasFollowing = _followingIds.contains(profile.id);
    setState(() {
      _busyFollowIds.add(profile.id);
      if (wasFollowing) {
        _followingIds.remove(profile.id);
      } else {
        _followingIds.add(profile.id);
      }
    });
    try {
      final nowFollowing = await widget.followService.toggleFollowing(
        profile.id,
      );
      if (!mounted) return;
      setState(() {
        _busyFollowIds.remove(profile.id);
        if (nowFollowing) {
          _followingIds.add(profile.id);
        } else {
          _followingIds.remove(profile.id);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyFollowIds.remove(profile.id);
        if (wasFollowing) {
          _followingIds.add(profile.id);
        } else {
          _followingIds.remove(profile.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar el seguimiento.')),
      );
      debugPrint('DISCOVER_PEOPLE_FOLLOW_ERROR error=$error');
    }
  }

  void _openProfile(CommunityProfile profile) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          profile: profile,
          currentUser: widget.currentUser,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03050B),
      appBar: AppBar(
        title: const Text('Descubrir personas'),
        backgroundColor: const Color(0xFF03050B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: TextField(
                    key: const ValueKey('discover-people-search'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o @usuario',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _searchController.clear();
                                _onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppTheme.panelRaised.withValues(alpha: 0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.violet.withValues(alpha: 0.42),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.violet.withValues(alpha: 0.32),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.cyan),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.cyan),
      );
    }
    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        action: TextButton(
          onPressed: _loadProfiles,
          child: const Text('Reintentar'),
        ),
      );
    }
    if (_profiles.isEmpty) {
      return _MessageState(
        icon: Icons.person_search_rounded,
        text: _query.isEmpty
            ? 'Todavía no hay personas para sugerir.'
            : 'No encontramos personas con ese nombre.',
      );
    }
    return ListView.separated(
      key: const ValueKey('discover-people-list'),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
      itemCount: _profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        return _DiscoverPersonTile(
          profile: profile,
          following: _followingIds.contains(profile.id),
          busy: _busyFollowIds.contains(profile.id),
          onOpen: () => _openProfile(profile),
          onFollow: () => _toggleFollow(profile),
        );
      },
    );
  }
}

class _DiscoverPersonTile extends StatelessWidget {
  const _DiscoverPersonTile({
    required this.profile,
    required this.following,
    required this.busy,
    required this.onOpen,
    required this.onFollow,
  });

  final CommunityProfile profile;
  final bool following;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final username = profile.username.trim();
    final visibleUsername = username.isEmpty
        ? 'Perfil HallyuHub'
        : username.startsWith('@')
        ? username
        : '@$username';
    return Container(
      key: ValueKey('discover-person-${profile.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(28),
            child: HubAvatar(
              asset: profile.avatarAsset,
              size: 52,
              isLive: profile.online,
              fallbackLabel: profile.name,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    visibleUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ValueKey('discover-follow-${profile.id}'),
            onPressed: busy ? null : onFollow,
            style: FilledButton.styleFrom(
              minimumSize: const Size(92, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: following
                  ? AppTheme.cyan.withValues(alpha: 0.16)
                  : AppTheme.violet.withValues(alpha: 0.7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(following ? 'Siguiendo' : 'Seguir'),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cyan.withValues(alpha: 0.85), size: 42),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
