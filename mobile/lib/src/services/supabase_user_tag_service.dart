import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import '../theme/app_theme.dart';
import 'local_user_tag_service.dart';

class SupabaseUserTagService extends LocalUserTagService {
  SupabaseUserTagService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealTags => true;

  @override
  Future<void> saveContentUserTags({
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<CommunityProfile> taggedUsers,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null || contentId.trim().isEmpty) return;
    final safeUsers = _uniqueProfiles(taggedUsers)
        .where((profile) => profile.id != authUser.id)
        .take(LocalUserTagService.maxTaggedUsersPerContent)
        .toList(growable: false);
    await _client
        .from('content_user_tags')
        .delete()
        .eq('content_type', contentType.key)
        .eq('content_id', contentId)
        .eq('tagged_by', authUser.id);
    if (safeUsers.isEmpty) {
      LocalUserTagService.revision.value++;
      return;
    }
    await _client
        .from('content_user_tags')
        .insert(
          safeUsers
              .map(
                (profile) => {
                  'content_type': contentType.key,
                  'content_id': contentId,
                  'tagged_user_id': profile.id,
                  'tagged_by': authUser.id,
                },
              )
              .toList(growable: false),
        );
    LocalUserTagService.revision.value++;
  }

  @override
  Future<List<ContentUserTag>> restoreForContent({
    required ProfileContentType contentType,
    required String contentId,
  }) async {
    final grouped = await restoreForContents(
      contentType: contentType,
      contentIds: [contentId],
    );
    return grouped[contentId] ?? const [];
  }

  @override
  Future<Map<String, List<ContentUserTag>>> restoreForContents({
    required ProfileContentType contentType,
    required Iterable<String> contentIds,
  }) async {
    final ids = contentIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('content_user_tags')
        .select(
          'content_type,content_id,tagged_user_id,tagged_by,created_at,'
          'profile:tagged_user_id(id,name,username,bio,avatar_asset,avatar_url,'
          'fandom,content_region,location_visibility,'
          'favorite_group)',
        )
        .eq('content_type', contentType.key)
        .inFilter('content_id', ids)
        .order('created_at', ascending: true);
    final grouped = <String, List<ContentUserTag>>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final tag = _tagFromRow(row);
      if (tag == null) continue;
      grouped.putIfAbsent(tag.contentId, () => []).add(tag);
    }
    return grouped;
  }

  List<CommunityProfile> _uniqueProfiles(Iterable<CommunityProfile> profiles) {
    final seen = <String>{};
    final result = <CommunityProfile>[];
    for (final profile in profiles) {
      if (profile.id.trim().isEmpty || !seen.add(profile.id)) continue;
      result.add(profile);
    }
    return result;
  }

  ContentUserTag? _tagFromRow(Map<String, dynamic> row) {
    final contentType = ProfileContentType.fromKey(
      row['content_type'] as String? ?? '',
    );
    final contentId = row['content_id'] as String? ?? '';
    final taggedUserId = row['tagged_user_id'] as String? ?? '';
    if (contentType == null || contentId.isEmpty || taggedUserId.isEmpty) {
      return null;
    }
    final profileRow = (row['profile'] as Map?)?.cast<String, dynamic>();
    return ContentUserTag(
      contentType: contentType,
      contentId: contentId,
      taggedUserId: taggedUserId,
      taggedBy: row['tagged_by'] as String? ?? '',
      profile: profileRow == null ? null : _profileFromRow(profileRow),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  CommunityProfile _profileFromRow(Map<String, dynamic> row) {
    final name = _string(row, 'name', 'Hallyu Fan');
    final username = _normalizeUsername(_string(row, 'username', name));
    final visibility = _string(row, 'location_visibility', 'country');
    final country = _string(row, 'country', '');
    final region = _string(row, 'region', '');
    final city = _string(row, 'city', '');
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
      id: row['id'] as String? ?? '',
      name: name,
      username: username,
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
      followers: '0',
      following: '0',
      posts: '0',
      starsReceived: '0',
      level: 1,
      coverAsset: 'assets/demo-posts/post-01.jpg',
      colors: _colorsFor(fandom),
      online: false,
    );
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

  String _normalizeUsername(String username) {
    final cleaned = username.replaceFirst('@', '').trim();
    return cleaned.isEmpty ? '@fan' : '@$cleaned';
  }

  String _string(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }
}
