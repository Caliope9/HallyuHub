import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import '../theme/app_theme.dart';
import 'local_follow_service.dart';

class SupabaseFollowService extends LocalFollowService {
  SupabaseFollowService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealProfiles => true;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const _profileSelect =
      'id,name,username,bio,avatar_asset,avatar_url,fandom,'
      'content_region,location_visibility,favorite_group,private_profile';

  static const _profileSelectWithAvatar =
      'id,name,username,bio,avatar_asset,avatar_url,fandom,private_profile';

  static const _minimalProfileSelect = 'id,name,username,bio';

  @override
  Future<Set<String>> restoreFollowingIds() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return {};
    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', currentUserId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['following_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  @override
  Future<bool> toggleFollowing(String profileId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw const FollowServiceException('Necesitás iniciar sesión.');
    }
    if (profileId == currentUserId) {
      throw const FollowServiceException('No podés seguir tu propio perfil.');
    }
    final following = await restoreFollowingIds();
    final shouldFollow = !following.contains(profileId);
    if (shouldFollow) {
      await _client.from('follows').upsert({
        'follower_id': currentUserId,
        'following_id': profileId,
      }, onConflict: 'follower_id,following_id');
    } else {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', profileId);
    }
    LocalFollowService.revision.value++;
    return shouldFollow;
  }

  @override
  Future<List<CommunityProfile>> restoreProfiles({
    String query = '',
    int limit = 30,
    bool excludeFollowing = false,
  }) async {
    final currentUserId = _currentUserId;
    final followingIds = excludeFollowing && currentUserId != null
        ? await restoreFollowingIds()
        : <String>{};
    final profileRows = (await _restoreProfileRows(limit: 500))
        .cast<Map<String, dynamic>>()
        .where((row) {
          final id = row['id'] as String?;
          if (id == null || id == currentUserId) return false;
          if (excludeFollowing && followingIds.contains(id)) return false;
          return true;
        })
        .toList(growable: false);
    final normalized = query.toLowerCase().trim();
    final filtered = profileRows
        .where((row) {
          if (normalized.isEmpty) return true;
          return [
            _string(row, 'id', ''),
            _string(row, 'name', ''),
            _string(row, 'username', ''),
            _string(row, 'country', ''),
            _string(row, 'region', ''),
            _string(row, 'city', ''),
            _string(row, 'content_region', ''),
            _string(row, 'fandom', ''),
            _string(row, 'favorite_group', ''),
            _string(row, 'bio', ''),
          ].join(' ').toLowerCase().contains(normalized);
        })
        .take(limit)
        .toList(growable: false);
    if (filtered.isEmpty) return const [];
    final ids = filtered.map((row) => row['id'] as String).toList();
    final followers = await _safeFollowCounts(
      countedColumn: 'following_id',
      ids: ids,
    );
    final following = await _safeFollowCounts(
      countedColumn: 'follower_id',
      ids: ids,
    );
    final posts = await _safePostCounts(ids);
    return filtered
        .map(
          (row) => _profileFromRow(
            row,
            followers: followers[row['id']] ?? 0,
            following: following[row['id']] ?? 0,
            posts: posts[row['id']] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CommunityProfile>> restoreFollowers(String profileId) async {
    try {
      final rows = await _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', profileId)
          .order('created_at', ascending: false)
          .limit(120);
      final ids = rows
          .cast<Map<String, dynamic>>()
          .map((row) => row['follower_id'] as String?)
          .whereType<String>()
          .toList(growable: false);
      return await _profilesByIds(ids);
    } catch (error) {
      debugPrint(
        'FOLLOW_LIST_ERROR followers profileId=$profileId error=$error',
      );
      rethrow;
    }
  }

  @override
  Future<List<CommunityProfile>> restoreCurrentUserFollowers() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const [];
    return restoreFollowers(currentUserId);
  }

  @override
  Future<List<CommunityProfile>> restoreFollowingProfiles(
    String profileId,
  ) async {
    try {
      final rows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', profileId)
          .order('created_at', ascending: false)
          .limit(120);
      final ids = rows
          .cast<Map<String, dynamic>>()
          .map((row) => row['following_id'] as String?)
          .whereType<String>()
          .toList(growable: false);
      return await _profilesByIds(ids);
    } catch (error) {
      debugPrint(
        'FOLLOW_LIST_ERROR following profileId=$profileId error=$error',
      );
      rethrow;
    }
  }

  @override
  Future<List<CommunityProfile>> restoreProfilesByIds(List<String> ids) =>
      _profilesByIds(ids);

  @override
  Future<List<CommunityProfile>> restoreCurrentUserFollowingProfiles() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const [];
    return restoreFollowingProfiles(currentUserId);
  }

  @override
  Future<FollowCounts> restoreCounts(String profileId) async {
    final followers = await _singleFollowCount(
      column: 'following_id',
      value: profileId,
    );
    final following = await _singleFollowCount(
      column: 'follower_id',
      value: profileId,
    );
    return FollowCounts(followers: followers, following: following);
  }

  @override
  Future<FollowCounts> restoreCurrentUserCounts() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const FollowCounts();
    return restoreCounts(currentUserId);
  }

  Future<int> _singleFollowCount({
    required String column,
    required String value,
  }) async {
    final rows = await _client.from('follows').select(column).eq(column, value);
    return rows.length;
  }

  Future<Map<String, int>> _followCounts({
    required String countedColumn,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('follows')
        .select(countedColumn)
        .inFilter(countedColumn, ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row[countedColumn] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _safeFollowCounts({
    required String countedColumn,
    required List<String> ids,
  }) async {
    try {
      return await _followCounts(countedColumn: countedColumn, ids: ids);
    } catch (error) {
      debugPrint(
        'FOLLOW_COUNT_ERROR column=$countedColumn ids=${ids.length} error=$error',
      );
      return {};
    }
  }

  Future<Map<String, int>> _postCounts(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('posts')
        .select('author_id')
        .eq('status', 'published')
        .filter('deleted_at', 'is', null)
        .inFilter('author_id', ids);
    final counts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row['author_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _safePostCounts(List<String> ids) async {
    try {
      return await _postCounts(ids);
    } catch (error) {
      debugPrint('FOLLOW_POST_COUNT_ERROR ids=${ids.length} error=$error');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _restoreProfileRows({
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(_profileSelect)
          .limit(limit);
      return rows.cast<Map<String, dynamic>>().toList(growable: false);
    } catch (error) {
      debugPrint('FOLLOW_PROFILE_RESTORE_ERROR primary error=$error');
      try {
        final rows = await _client
            .from('profiles')
            .select(_profileSelectWithAvatar)
            .limit(limit);
        return rows.cast<Map<String, dynamic>>().toList(growable: false);
      } catch (fallbackError) {
        debugPrint(
          'FOLLOW_PROFILE_RESTORE_ERROR avatarFallback error=$fallbackError',
        );
        final rows = await _client
            .from('profiles')
            .select(_minimalProfileSelect)
            .limit(limit);
        return rows.cast<Map<String, dynamic>>().toList(growable: false);
      }
    }
  }

  CommunityProfile _profileFromRow(
    Map<String, dynamic> row, {
    required int followers,
    required int following,
    required int posts,
  }) {
    final name = _string(row, 'name', 'Hallyu Fan');
    final country = _string(row, 'country', '');
    final region = _string(row, 'region', '');
    final city = _string(row, 'city', '');
    final visibility = _string(row, 'location_visibility', 'country');
    final publicCity = switch (visibility) {
      'city' =>
        city.isNotEmpty
            ? city
            : region.isNotEmpty
            ? region
            : country,
      'hidden' => '',
      _ => country,
    };
    final fandom = _string(row, 'fandom', 'Hallyu');
    return CommunityProfile(
      id: row['id'] as String,
      name: name,
      username: _normalizeUsername(_string(row, 'username', name)),
      city: publicCity,
      country: visibility == 'hidden' ? '' : country,
      fandom: fandom,
      favoriteGroup: _string(row, 'favorite_group', 'K-pop'),
      bio: _string(row, 'bio', 'Fan de HallyuHub preparando su perfil.'),
      avatarAsset: _string(
        row,
        'avatar_url',
        _string(row, 'avatar_asset', 'assets/demo-users/user-01.jpg'),
      ),
      followers: _formatCount(followers),
      following: _formatCount(following),
      posts: _formatCount(posts),
      starsReceived: '0',
      level: 1,
      coverAsset: 'assets/demo-posts/post-01.jpg',
      colors: _colorsFor(fandom),
      online: false,
      privateProfile: _bool(row, 'private_profile', false),
      role: _string(row, 'role', 'user'),
    );
  }

  Future<List<CommunityProfile>> _profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _restoreProfileRowsByIds(ids);
    final profilesById = {
      for (final row in rows.cast<Map<String, dynamic>>())
        row['id'] as String: row,
    };
    final followers = await _safeFollowCounts(
      countedColumn: 'following_id',
      ids: ids,
    );
    final following = await _safeFollowCounts(
      countedColumn: 'follower_id',
      ids: ids,
    );
    final posts = await _safePostCounts(ids);
    final result = <CommunityProfile>[];
    for (final id in ids) {
      final row = profilesById[id];
      if (row == null) continue;
      result.add(
        _profileFromRow(
          row,
          followers: followers[id] ?? 0,
          following: following[id] ?? 0,
          posts: posts[id] ?? 0,
        ),
      );
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _restoreProfileRowsByIds(
    List<String> ids,
  ) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(_profileSelect)
          .inFilter('id', ids);
      return rows.cast<Map<String, dynamic>>().toList(growable: false);
    } catch (error) {
      debugPrint(
        'FOLLOW_PROFILE_LIST_RESTORE_ERROR ids=${ids.length} error=$error',
      );
      try {
        final rows = await _client
            .from('profiles')
            .select(_profileSelectWithAvatar)
            .inFilter('id', ids);
        return rows.cast<Map<String, dynamic>>().toList(growable: false);
      } catch (fallbackError) {
        debugPrint(
          'FOLLOW_PROFILE_LIST_RESTORE_ERROR avatarFallback ids=${ids.length} error=$fallbackError',
        );
        final rows = await _client
            .from('profiles')
            .select(_minimalProfileSelect)
            .inFilter('id', ids);
        return rows.cast<Map<String, dynamic>>().toList(growable: false);
      }
    }
  }

  List<Color> _colorsFor(String fandom) {
    final lower = fandom.toLowerCase();
    if (lower.contains('army') || lower.contains('bts')) {
      return [AppTheme.violet, AppTheme.cyan, AppTheme.night];
    }
    if (lower.contains('blink') || lower.contains('blackpink')) {
      return [AppTheme.rose, AppTheme.violet, AppTheme.night];
    }
    return [AppTheme.cyan, AppTheme.rose, AppTheme.night];
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _normalizeUsername(String username) {
    final cleaned = username.replaceFirst('@', '').trim();
    return cleaned.isEmpty ? '@fan' : '@$cleaned';
  }

  String _string(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  bool _bool(Map<String, dynamic> json, String key, bool fallback) {
    final value = json[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }
}

class FollowServiceException implements Exception {
  const FollowServiceException(this.message);

  final String message;

  @override
  String toString() => 'FollowServiceException: $message';
}
