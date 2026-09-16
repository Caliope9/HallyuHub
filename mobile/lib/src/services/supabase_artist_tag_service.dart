import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_artist_tag_service.dart';
import 'supabase_artist_tag_hydrator.dart';

class SupabaseArtistTagService extends LocalArtistTagService {
  SupabaseArtistTagService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealArtistTags => true;

  @override
  Future<List<KpopEntity>> searchEntities({
    String query = '',
    int limit = 20,
  }) async {
    final normalized = _normalize(query);
    final rows = await _client
        .from('kpop_entities')
        .select(
          'id,entity_type,name,normalized_name,aliases,bio,image_url,'
          'image_source,image_license,attribution,fandom_name,is_verified',
        )
        .order('is_verified', ascending: false)
        .order('name', ascending: true)
        .limit(normalized.isEmpty ? limit.clamp(1, 50) : 120);
    final entities = rows
        .cast<Map<String, dynamic>>()
        .map(_entityFromRow)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return entities.take(limit).toList(growable: false);
    }
    return entities
        .where((entity) => entity.searchableText.contains(normalized))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> saveContentArtistTags({
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<KpopEntity> entities,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null || contentId.trim().isEmpty) return;
    final safeEntities = _uniqueEntities(
      entities,
    ).take(LocalArtistTagService.maxTaggedEntitiesPerContent).toList();
    await _client
        .from('content_artist_tags')
        .delete()
        .eq('content_type', contentType.key)
        .eq('content_id', contentId)
        .eq('tagged_by', authUser.id);
    if (safeEntities.isEmpty) {
      LocalArtistTagService.revision.value++;
      return;
    }
    await _client
        .from('content_artist_tags')
        .insert(
          safeEntities
              .map(
                (entity) => {
                  'content_type': contentType.key,
                  'content_id': contentId,
                  'entity_id': entity.id,
                  'tagged_by': authUser.id,
                },
              )
              .toList(growable: false),
        );
    LocalArtistTagService.revision.value++;
  }

  @override
  Future<Map<String, List<ContentArtistTag>>> restoreForContents({
    required ProfileContentType contentType,
    required Iterable<String> contentIds,
  }) async {
    final ids = contentIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('content_artist_tags')
        .select(
          'content_type,content_id,entity_id,tagged_by,created_at,'
          'entity:entity_id(id,entity_type,name,normalized_name,aliases,bio,'
          'image_url,image_source,image_license,attribution,is_verified)',
        )
        .eq('content_type', contentType.key)
        .inFilter('content_id', ids)
        .order('created_at', ascending: true);
    final grouped = <String, List<ContentArtistTag>>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final tag = _tagFromRow(row);
      if (tag == null) continue;
      grouped.putIfAbsent(tag.contentId, () => []).add(tag);
    }
    return hydrateContentArtistTags(client: _client, grouped: grouped);
  }

  @override
  Future<List<String>> restoreContentIdsForEntity({
    required ProfileContentType contentType,
    required String entityId,
  }) async {
    if (entityId.trim().isEmpty) return const [];
    final rows = await _client
        .from('content_artist_tags')
        .select('content_id')
        .eq('content_type', contentType.key)
        .eq('entity_id', entityId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['content_id'] as String? ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  @override
  Future<List<ContentArtistTag>> restoreForContent({
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
  Future<void> submitEntitySuggestion({
    required String name,
    required KpopEntityType type,
  }) async {
    final suggestionType = switch (type) {
      KpopEntityType.group => KpopEntitySuggestionType.group,
      KpopEntityType.idol => KpopEntitySuggestionType.idol,
      KpopEntityType.artist => KpopEntitySuggestionType.artist,
    };
    await submitDetailedEntitySuggestion(
      ArtistSuggestionDraft(name: name, type: suggestionType),
    );
  }

  @override
  Future<void> submitDetailedEntitySuggestion(
    ArtistSuggestionDraft draft,
  ) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    final name = draft.name.trim();
    if (name.isEmpty) return;
    await _client.from('artist_suggestions').insert({
      'name': name,
      'normalized_name': _normalize(name),
      'type': draft.type.key,
      'fandom': _nullable(draft.fandom),
      'country': _nullable(draft.country),
      'agency': _nullable(draft.agency),
      'official_url': _nullable(draft.officialUrl),
      'note': _nullable(draft.note),
      'suggested_by': authUser.id,
      'status': 'pending',
    });
  }

  @override
  Future<ArtistSuggestionAdminData> restoreAdminEntitySuggestions({
    String status = 'pending',
    String type = 'all',
    String query = '',
  }) async {
    dynamic request = _client
        .from('artist_suggestions')
        .select(
          'id,suggested_by,name,normalized_name,type,fandom,country,agency,'
          'official_url,note,status,reviewed_by,reviewed_at,created_at,'
          'updated_at,admin_notes,approved_entity_id,'
          'suggester:suggested_by(name,username,email)',
        );
    if (status != 'all') request = request.eq('status', status);
    if (type != 'all') request = request.eq('type', type);
    final rows = await request.order('created_at', ascending: false).limit(300);
    final normalizedQuery = query.trim().toLowerCase();
    final entries = rows
        .cast<Map<String, dynamic>>()
        .map(_suggestionFromRow)
        .where((entry) {
          if (normalizedQuery.isEmpty) return true;
          return [
            entry.name,
            entry.normalizedName,
            entry.fandom,
            entry.country,
            entry.agency,
            entry.officialUrl,
            entry.note,
            entry.adminNotes,
            entry.suggesterName,
            entry.suggesterUsername,
            entry.suggesterEmail,
          ].join(' ').toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    return ArtistSuggestionAdminData(entries: entries);
  }

  @override
  Future<void> updateEntitySuggestion({
    required String id,
    required ArtistSuggestionStatus status,
    String? name,
    KpopEntitySuggestionType? type,
    String? adminNotes,
  }) async {
    final safeId = id.trim();
    if (safeId.isEmpty) return;
    if (status == ArtistSuggestionStatus.approved) {
      await _client.rpc(
        'approve_artist_suggestion',
        params: {
          'p_suggestion_id': safeId,
          'p_name': _nullable(name),
          'p_type': type?.key,
          'p_admin_notes': _nullable(adminNotes),
        },
      );
      return;
    }
    final payload = <String, dynamic>{
      'status': status.key,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final authUser = _client.auth.currentUser;
    if (authUser != null) payload['reviewed_by'] = authUser.id;
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
      payload['normalized_name'] = _normalize(name);
    }
    if (type != null) payload['type'] = type.key;
    if (adminNotes != null) payload['admin_notes'] = adminNotes.trim();
    await _client.from('artist_suggestions').update(payload).eq('id', safeId);
  }

  List<KpopEntity> _uniqueEntities(Iterable<KpopEntity> entities) {
    final seen = <String>{};
    final result = <KpopEntity>[];
    for (final entity in entities) {
      if (entity.id.trim().isEmpty || !seen.add(entity.id)) continue;
      result.add(entity);
    }
    return result;
  }

  ContentArtistTag? _tagFromRow(Map<String, dynamic> row) {
    final contentType = ProfileContentType.fromKey(
      row['content_type'] as String? ?? '',
    );
    final contentId = row['content_id'] as String? ?? '';
    final entityId = row['entity_id'] as String? ?? '';
    if (contentType == null || contentId.isEmpty || entityId.isEmpty) {
      return null;
    }
    final entityRow = (row['entity'] as Map?)?.cast<String, dynamic>();
    return ContentArtistTag(
      contentType: contentType,
      contentId: contentId,
      entityId: entityId,
      taggedBy: row['tagged_by'] as String? ?? '',
      entity: entityRow == null ? null : _entityFromRow(entityRow),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
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

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _nullable(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  ArtistSuggestionEntry _suggestionFromRow(Map<String, dynamic> row) {
    final suggester = (row['suggester'] as Map?)?.cast<String, dynamic>();
    return ArtistSuggestionEntry(
      id: row['id'] as String? ?? '',
      suggestedBy: row['suggested_by'] as String? ?? '',
      name: row['name'] as String? ?? '',
      normalizedName: row['normalized_name'] as String? ?? '',
      type: KpopEntitySuggestionType.fromKey(row['type'] as String? ?? ''),
      fandom: row['fandom'] as String? ?? '',
      country: row['country'] as String? ?? '',
      agency: row['agency'] as String? ?? '',
      officialUrl: row['official_url'] as String? ?? '',
      note: row['note'] as String? ?? '',
      status: ArtistSuggestionStatus.fromKey(row['status'] as String? ?? ''),
      reviewedBy: row['reviewed_by'] as String? ?? '',
      reviewedAt: DateTime.tryParse(row['reviewed_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      adminNotes: row['admin_notes'] as String? ?? '',
      approvedEntityId: row['approved_entity_id'] as String? ?? '',
      suggesterName: suggester?['name'] as String? ?? '',
      suggesterUsername: suggester?['username'] as String? ?? '',
      suggesterEmail: suggester?['email'] as String? ?? '',
    );
  }
}
