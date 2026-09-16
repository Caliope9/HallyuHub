import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalUserTagService {
  const LocalUserTagService();

  static const _tagsKey = 'hallyuhub.local-user-tags.v1';
  static const maxTaggedUsersPerContent = 10;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealTags => false;

  Future<void> saveContentUserTags({
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<CommunityProfile> taggedUsers,
  }) async {
    final safeUsers = _uniqueProfiles(
      taggedUsers,
    ).take(maxTaggedUsersPerContent);
    final rows = await _restoreRows();
    rows.removeWhere(
      (row) => row.contentType == contentType && row.contentId == contentId,
    );
    rows.addAll(
      safeUsers.map(
        (profile) => ContentUserTag(
          contentType: contentType,
          contentId: contentId,
          taggedUserId: profile.id,
          taggedBy: 'local-user',
          profile: profile,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await _saveRows(rows);
    revision.value++;
  }

  Future<List<ContentUserTag>> restoreForContent({
    required ProfileContentType contentType,
    required String contentId,
  }) async {
    final rows = await _restoreRows();
    return rows
        .where(
          (row) => row.contentType == contentType && row.contentId == contentId,
        )
        .toList(growable: false);
  }

  Future<Map<String, List<ContentUserTag>>> restoreForContents({
    required ProfileContentType contentType,
    required Iterable<String> contentIds,
  }) async {
    final ids = contentIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    final rows = await _restoreRows();
    final grouped = <String, List<ContentUserTag>>{};
    for (final row in rows) {
      if (row.contentType != contentType || !ids.contains(row.contentId)) {
        continue;
      }
      grouped.putIfAbsent(row.contentId, () => []).add(row);
    }
    return grouped;
  }

  List<CommunityProfile> _uniqueProfiles(Iterable<CommunityProfile> profiles) {
    final seen = <String>{};
    final result = <CommunityProfile>[];
    for (final profile in profiles) {
      if (profile.id.trim().isEmpty) continue;
      if (!seen.add(profile.id)) continue;
      result.add(profile);
    }
    return result;
  }

  Future<List<ContentUserTag>> _restoreRows() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_tagsKey);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .whereType<ContentUserTag>()
          .toList();
    } catch (_) {
      await preferences.remove(_tagsKey);
      return [];
    }
  }

  Future<void> _saveRows(List<ContentUserTag> rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _tagsKey,
      jsonEncode(rows.map(_toJson).toList()),
    );
  }

  ContentUserTag? _fromJson(Map<String, dynamic> json) {
    final contentType = ProfileContentType.fromKey(
      json['contentType'] as String? ?? '',
    );
    if (contentType == null) return null;
    final profileJson = (json['profile'] as Map?)?.cast<String, dynamic>();
    return ContentUserTag(
      contentType: contentType,
      contentId: json['contentId'] as String? ?? '',
      taggedUserId: json['taggedUserId'] as String? ?? '',
      taggedBy: json['taggedBy'] as String? ?? 'local-user',
      profile: profileJson == null ? null : _profileFromJson(profileJson),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> _toJson(ContentUserTag row) {
    return {
      'contentType': row.contentType.key,
      'contentId': row.contentId,
      'taggedUserId': row.taggedUserId,
      'taggedBy': row.taggedBy,
      'profile': row.profile == null ? null : _profileToJson(row.profile!),
      'createdAt': row.createdAt?.toIso8601String(),
    };
  }

  CommunityProfile _profileFromJson(Map<String, dynamic> json) {
    return CommunityProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Hallyu Fan',
      username: json['username'] as String? ?? '@fan',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      fandom: json['fandom'] as String? ?? 'Hallyu',
      favoriteGroup: json['favoriteGroup'] as String? ?? 'K-pop',
      bio: json['bio'] as String? ?? '',
      avatarAsset:
          json['avatarAsset'] as String? ?? 'assets/demo-users/user-01.jpg',
      followers: json['followers'] as String? ?? '0',
      following: json['following'] as String? ?? '0',
      posts: json['posts'] as String? ?? '0',
      starsReceived: json['starsReceived'] as String? ?? '0',
      level: json['level'] as int? ?? 1,
      coverAsset:
          json['coverAsset'] as String? ?? 'assets/demo-posts/post-01.jpg',
      colors: const [Color(0xFF39E6E6), Color(0xFFEF4F7A), Color(0xFF080313)],
      online: json['online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _profileToJson(CommunityProfile profile) {
    return {
      'id': profile.id,
      'name': profile.name,
      'username': profile.username,
      'city': profile.city,
      'country': profile.country,
      'fandom': profile.fandom,
      'favoriteGroup': profile.favoriteGroup,
      'bio': profile.bio,
      'avatarAsset': profile.avatarAsset,
      'followers': profile.followers,
      'following': profile.following,
      'posts': profile.posts,
      'starsReceived': profile.starsReceived,
      'level': profile.level,
      'coverAsset': profile.coverAsset,
      'online': profile.online,
    };
  }
}
