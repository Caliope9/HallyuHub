import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_data.dart';
import '../models.dart';

class FollowCounts {
  const FollowCounts({this.followers = 0, this.following = 0});

  final int followers;
  final int following;
}

class LocalFollowService {
  const LocalFollowService();

  static const _followingKey = 'hallyuhub.following-profile-ids.v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealProfiles => false;

  Future<Set<String>> restoreFollowingIds() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_followingKey);
    if (stored == null) return {};
    try {
      return (jsonDecode(stored) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      await preferences.remove(_followingKey);
      return {};
    }
  }

  Future<bool> toggleFollowing(String profileId) async {
    final following = await restoreFollowingIds();
    final nowFollowing = following.add(profileId);
    if (!nowFollowing) {
      following.remove(profileId);
    }
    await _save(following);
    revision.value++;
    return nowFollowing;
  }

  Future<List<CommunityProfile>> restoreProfiles({
    String query = '',
    int limit = 30,
    bool excludeFollowing = false,
  }) async {
    final normalized = query.toLowerCase().trim();
    final source = normalized.isEmpty ? suggestedProfiles : demoProfiles;
    final following = excludeFollowing
        ? await restoreFollowingIds()
        : <String>{};
    return source
        .where((profile) {
          if (excludeFollowing && following.contains(profile.id)) return false;
          if (normalized.isEmpty) return true;
          return [
            profile.name,
            profile.username,
            profile.city,
            profile.country,
            profile.fandom,
            profile.favoriteGroup,
            profile.bio,
          ].join(' ').toLowerCase().contains(normalized);
        })
        .take(limit)
        .toList(growable: false);
  }

  Future<List<CommunityProfile>> restoreProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final requested = ids.toSet();
    final profiles = await restoreProfiles(limit: 500);
    return profiles
        .where((profile) => requested.contains(profile.id))
        .toList(growable: false);
  }

  Future<List<CommunityProfile>> restoreFollowers(String profileId) async {
    if (profileId == 'local-user') {
      return demoProfiles.take(12).toList(growable: false);
    }
    return demoProfiles
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
  }

  Future<List<CommunityProfile>> restoreCurrentUserFollowers() =>
      restoreFollowers('local-user');

  Future<List<CommunityProfile>> restoreFollowingProfiles(
    String profileId,
  ) async {
    if (profileId != 'local-user') {
      final candidates = demoProfiles
          .where((profile) => profile.id != profileId)
          .toList(growable: false);
      return candidates
          .take(candidates.length > 2 ? 2 : candidates.length)
          .toList();
    }
    final following = await restoreFollowingIds();
    return demoProfiles
        .where((profile) => following.contains(profile.id))
        .toList(growable: false);
  }

  Future<List<CommunityProfile>> restoreCurrentUserFollowingProfiles() =>
      restoreFollowingProfiles('local-user');

  Future<FollowCounts> restoreCounts(String profileId) async {
    final following = await restoreFollowingIds();
    if (profileId == 'local-user') {
      return FollowCounts(
        followers: _demoFollowersForOwnProfile,
        following: following.length,
      );
    }
    final profile = demoProfileById(profileId);
    return FollowCounts(
      followers: _parseCompactCount(profile.followers),
      following: _parseCompactCount(profile.following),
    );
  }

  Future<FollowCounts> restoreCurrentUserCounts() =>
      restoreCounts('local-user');

  Future<void> _save(Set<String> following) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_followingKey, jsonEncode(following.toList()));
  }

  int get _demoFollowersForOwnProfile => demoProfiles.length - 1;

  int _parseCompactCount(String value) {
    final normalized = value.trim().toUpperCase();
    final multiplier = normalized.endsWith('K')
        ? 1000
        : normalized.endsWith('M')
        ? 1000000
        : 1;
    final number = double.tryParse(
      normalized.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    return ((number ?? 0) * multiplier).round();
  }
}
