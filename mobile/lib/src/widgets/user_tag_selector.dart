import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_follow_service.dart';
import '../theme/app_theme.dart';
import 'hub_avatar.dart';

class UserTagSelector extends StatefulWidget {
  const UserTagSelector({
    super.key,
    required this.followService,
    required this.selectedUsers,
    required this.onChanged,
    this.currentUser,
    this.title = 'Etiquetar personas',
    this.subtitle = 'Buscá fans reales por nombre o @usuario.',
    this.compact = false,
    this.searchFieldKey,
    this.showEmptyOnlyAfterSearch = false,
  });

  final LocalFollowService followService;
  final AuthUser? currentUser;
  final List<CommunityProfile> selectedUsers;
  final ValueChanged<List<CommunityProfile>> onChanged;
  final String title;
  final String subtitle;
  final bool compact;
  final Key? searchFieldKey;
  final bool showEmptyOnlyAfterSearch;

  @override
  State<UserTagSelector> createState() => _UserTagSelectorState();
}

class _UserTagSelectorState extends State<UserTagSelector> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<CommunityProfile> _suggestions = const [];
  Set<String> _followingIds = const {};
  Set<String> _followerIds = const {};
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final following = await widget.followService.restoreFollowingIds();
      final followers = await widget.followService
          .restoreCurrentUserFollowers();
      if (!mounted) return;
      setState(() {
        _followingIds = following;
        _followerIds = followers.map((profile) => profile.id).toSet();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followingIds = const {};
        _followerIds = const {};
      });
    }
    if (!mounted) return;
    setState(() {
      _suggestions = const [];
      _loading = false;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search(value);
    });
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.replaceFirst('@', '').trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _query = '';
        _suggestions = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _loading = true;
    });
    try {
      final results = await widget.followService.restoreProfiles(
        query: query,
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = _prioritize(results);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
    }
  }

  List<CommunityProfile> _prioritize(List<CommunityProfile> profiles) {
    final selectedIds = widget.selectedUsers
        .map((profile) => profile.id)
        .toSet();
    final currentUsername = _cleanUsername(widget.currentUser?.username ?? '');
    final filtered = profiles
        .where((profile) => profile.id.isNotEmpty)
        .where((profile) => _cleanUsername(profile.username) != currentUsername)
        .where((profile) => !selectedIds.contains(profile.id))
        .toList(growable: false);
    final sorted = [...filtered]
      ..sort((a, b) => _priority(a).compareTo(_priority(b)));
    return sorted.take(12).toList(growable: false);
  }

  int _priority(CommunityProfile profile) {
    final follows = _followingIds.contains(profile.id);
    final follower = _followerIds.contains(profile.id);
    if (follows && follower) return 0;
    if (follows) return 1;
    if (follower) return 2;
    return 3;
  }

  void _add(CommunityProfile profile) {
    if (widget.selectedUsers.length >= 10) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Podés etiquetar hasta 10 personas.')),
        );
      return;
    }
    final selected = [...widget.selectedUsers];
    if (selected.any((item) => item.id == profile.id)) return;
    selected.add(profile);
    widget.onChanged(selected);
    _controller.clear();
    _search('');
  }

  void _remove(CommunityProfile profile) {
    widget.onChanged(
      widget.selectedUsers
          .where((item) => item.id != profile.id)
          .toList(growable: false),
    );
    _search(_query);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedUsers;
    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alternate_email_rounded, color: AppTheme.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!widget.compact)
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .58),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected
                  .map(
                    (profile) => InputChip(
                      avatar: HubAvatar(asset: profile.avatarAsset, size: 24),
                      label: Text(_displayUsername(profile)),
                      onDeleted: () => _remove(profile),
                      deleteIconColor: Colors.white70,
                      backgroundColor: AppTheme.rose.withValues(alpha: .18),
                      side: BorderSide(
                        color: AppTheme.rose.withValues(alpha: .36),
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: widget.searchFieldKey,
            controller: _controller,
            onChanged: _onQueryChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar @usuario o nombre',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: .45)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.cyan,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: .12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: .12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.cyan),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
              ),
            )
          else if (_suggestions.isEmpty &&
              (!widget.showEmptyOnlyAfterSearch || _query.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No encontramos fans con ese nombre.',
                style: TextStyle(color: Colors.white.withValues(alpha: .58)),
              ),
            )
          else
            ..._suggestions.map(_SuggestionTile.new),
        ],
      ),
    );
  }

  String _displayUsername(CommunityProfile profile) {
    final username = profile.username.trim();
    if (username.isEmpty) return profile.name;
    return username.startsWith('@') ? username : '@$username';
  }

  String _cleanUsername(String value) =>
      value.replaceFirst('@', '').trim().toLowerCase();
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile(this.profile);

  final CommunityProfile profile;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_UserTagSelectorState>()!;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: HubAvatar(asset: profile.avatarAsset, size: 42),
        title: Text(
          profile.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${state._displayUsername(profile)} · ${profile.fandom}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: .55)),
        ),
        trailing: IconButton(
          tooltip: 'Etiquetar',
          onPressed: () => state._add(profile),
          icon: const Icon(Icons.add_circle_rounded, color: AppTheme.cyan),
        ),
        onTap: () => state._add(profile),
      ),
    );
  }
}
