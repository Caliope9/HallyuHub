import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';

Future<Map<String, List<ContentArtistTag>>> hydrateContentArtistTags({
  required supabase.SupabaseClient client,
  required Map<String, List<ContentArtistTag>> grouped,
}) async {
  final missingIds = grouped.values
      .expand((tags) => tags)
      .where((tag) => tag.entity == null && tag.entityId.trim().isNotEmpty)
      .map((tag) => tag.entityId)
      .toSet()
      .toList(growable: false);
  if (missingIds.isEmpty) return grouped;
  try {
    final rows = await client
        .from('kpop_entities')
        .select(
          'id,entity_type,name,normalized_name,aliases,bio,image_url,'
          'image_source,image_license,attribution,fandom_name,is_verified',
        )
        .inFilter('id', missingIds);
    final entities = <String, KpopEntity>{
      for (final row in rows.cast<Map<String, dynamic>>())
        if ((row['id'] as String? ?? '').trim().isNotEmpty)
          row['id'] as String: _entityFromRow(row),
    };
    if (entities.isEmpty) return grouped;
    return <String, List<ContentArtistTag>>{
      for (final entry in grouped.entries)
        entry.key: entry.value
            .map((tag) {
              final entity = tag.entity ?? entities[tag.entityId];
              if (entity == null || identical(entity, tag.entity)) return tag;
              return ContentArtistTag(
                contentType: tag.contentType,
                contentId: tag.contentId,
                entityId: tag.entityId,
                taggedBy: tag.taggedBy,
                entity: entity,
                createdAt: tag.createdAt,
              );
            })
            .toList(growable: false),
    };
  } catch (error) {
    debugPrint('ARTIST_TAG_ENTITY_HYDRATION_ERROR $error');
    return grouped;
  }
}

KpopEntity _entityFromRow(Map<String, dynamic> row) {
  return KpopEntity(
    id: row['id'] as String? ?? '',
    type: KpopEntityType.fromKey(row['entity_type'] as String? ?? 'artist'),
    name: row['name'] as String? ?? 'Artista',
    normalizedName: row['normalized_name'] as String? ?? '',
    aliases: (row['aliases'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    bio: row['bio'] as String? ?? '',
    imageUrl: row['image_url'] as String? ?? '',
    imageSource: row['image_source'] as String? ?? '',
    imageLicense: row['image_license'] as String? ?? '',
    attribution: row['attribution'] as String? ?? '',
    fandomName: row['fandom_name'] as String? ?? '',
    verified: row['is_verified'] as bool? ?? false,
  );
}
