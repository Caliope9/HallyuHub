import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';

enum TopKpopType { groups, artists }

class TopKpopEntry {
  const TopKpopEntry({
    required this.entityId,
    required this.entityType,
    required this.name,
    required this.imageUrl,
    required this.isVerified,
    required this.followerCount,
    required this.isFollowing,
  });

  final String entityId;
  final String entityType;
  final String name;
  final String imageUrl;
  final bool isVerified;
  final int followerCount;
  final bool isFollowing;

  KpopEntity toEntity() => KpopEntity(
    id: entityId,
    type: KpopEntityType.fromKey(entityType),
    name: name,
    imageUrl: imageUrl,
    verified: isVerified,
  );

  factory TopKpopEntry.fromRow(Map<String, dynamic> row) {
    final rawCount = row['follower_count'];
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse('$rawCount') ?? 0;
    return TopKpopEntry(
      entityId: row['entity_id']?.toString() ?? '',
      entityType: row['entity_type']?.toString() ?? 'artist',
      name: row['name']?.toString() ?? '',
      imageUrl: row['image_url']?.toString() ?? '',
      isVerified: row['is_verified'] == true,
      followerCount: count < 0 ? 0 : count,
      isFollowing: row['is_following'] == true,
    );
  }
}

abstract class TopKpopService {
  Future<List<TopKpopEntry>> restorePage({
    required TopKpopType type,
    required int limit,
    required int offset,
  });
}

class SupabaseTopKpopService implements TopKpopService {
  SupabaseTopKpopService([supabase.SupabaseClient? client])
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  Future<List<TopKpopEntry>> restorePage({
    required TopKpopType type,
    required int limit,
    required int offset,
  }) async {
    final response = await _client.rpc(
      'hallyu_top_kpop_v1',
      params: {
        'p_type': type == TopKpopType.groups ? 'group' : 'artist',
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => TopKpopEntry.fromRow(Map<String, dynamic>.from(row)))
        .where((entry) => entry.entityId.isNotEmpty && entry.name.isNotEmpty)
        .toList(growable: false);
  }
}
