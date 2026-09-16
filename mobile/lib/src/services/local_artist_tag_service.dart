import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/discover_data.dart';
import '../models.dart';

enum KpopEntitySuggestionType {
  group('group', 'Grupo'),
  idol('idol', 'Idol'),
  soloist('soloist', 'Solista'),
  artist('artist', 'Artista'),
  other('other', 'Otro');

  const KpopEntitySuggestionType(this.key, this.label);

  final String key;
  final String label;

  KpopEntityType get catalogType {
    return switch (this) {
      KpopEntitySuggestionType.group => KpopEntityType.group,
      KpopEntitySuggestionType.idol => KpopEntityType.idol,
      KpopEntitySuggestionType.soloist ||
      KpopEntitySuggestionType.artist ||
      KpopEntitySuggestionType.other => KpopEntityType.artist,
    };
  }

  static KpopEntitySuggestionType fromKey(String key) {
    for (final type in values) {
      if (type.key == key) return type;
    }
    return KpopEntitySuggestionType.artist;
  }
}

enum ArtistSuggestionStatus {
  pending('pending', 'Pendiente'),
  approved('approved', 'Aprobada'),
  rejected('rejected', 'Rechazada'),
  duplicate('duplicate', 'Duplicada');

  const ArtistSuggestionStatus(this.key, this.label);

  final String key;
  final String label;

  static ArtistSuggestionStatus fromKey(String key) {
    for (final status in values) {
      if (status.key == key) return status;
    }
    return ArtistSuggestionStatus.pending;
  }
}

class ArtistSuggestionDraft {
  const ArtistSuggestionDraft({
    required this.name,
    required this.type,
    this.fandom = '',
    this.country = '',
    this.agency = '',
    this.officialUrl = '',
    this.note = '',
  });

  final String name;
  final KpopEntitySuggestionType type;
  final String fandom;
  final String country;
  final String agency;
  final String officialUrl;
  final String note;
}

class ArtistSuggestionEntry {
  const ArtistSuggestionEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.suggestedBy = '',
    this.suggesterName = '',
    this.suggesterUsername = '',
    this.suggesterEmail = '',
    this.fandom = '',
    this.country = '',
    this.agency = '',
    this.officialUrl = '',
    this.note = '',
    this.adminNotes = '',
    this.reviewedBy = '',
    this.reviewedAt,
    this.approvedEntityId = '',
  });

  final String id;
  final String name;
  final String normalizedName;
  final KpopEntitySuggestionType type;
  final ArtistSuggestionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String suggestedBy;
  final String suggesterName;
  final String suggesterUsername;
  final String suggesterEmail;
  final String fandom;
  final String country;
  final String agency;
  final String officialUrl;
  final String note;
  final String adminNotes;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final String approvedEntityId;

  String get displayAuthor {
    final username = suggesterUsername.trim();
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    if (suggesterName.trim().isNotEmpty) return suggesterName.trim();
    if (suggesterEmail.trim().isNotEmpty) return suggesterEmail.trim();
    return 'Usuario de acceso anticipado';
  }
}

class ArtistSuggestionAdminData {
  const ArtistSuggestionAdminData({required this.entries});

  final List<ArtistSuggestionEntry> entries;

  int get total => entries.length;
  int get pending => entries
      .where((entry) => entry.status == ArtistSuggestionStatus.pending)
      .length;
  int get approved => entries
      .where((entry) => entry.status == ArtistSuggestionStatus.approved)
      .length;
  int get rejected => entries
      .where((entry) => entry.status == ArtistSuggestionStatus.rejected)
      .length;
  int get duplicate => entries
      .where((entry) => entry.status == ArtistSuggestionStatus.duplicate)
      .length;
}

class LocalArtistTagService {
  const LocalArtistTagService();

  static const _tagsKey = 'hallyuhub.local-artist-tags.v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static const maxTaggedEntitiesPerContent = 10;

  bool get usesRealArtistTags => false;

  Future<List<KpopEntity>> searchEntities({
    String query = '',
    int limit = 20,
  }) async {
    final normalized = _normalize(query);
    final source = _localEntities();
    final filtered = normalized.isEmpty
        ? source
        : source
              .where((entity) => entity.searchableText.contains(normalized))
              .toList(growable: false);
    return filtered.take(limit).toList(growable: false);
  }

  Future<void> saveContentArtistTags({
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<KpopEntity> entities,
  }) async {
    final safeEntities = _uniqueEntities(
      entities,
    ).take(maxTaggedEntitiesPerContent);
    final rows = await _restoreRows();
    rows.removeWhere(
      (row) => row.contentType == contentType && row.contentId == contentId,
    );
    rows.addAll(
      safeEntities.map(
        (entity) => ContentArtistTag(
          contentType: contentType,
          contentId: contentId,
          entityId: entity.id,
          taggedBy: 'local-user',
          entity: entity,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await _saveRows(rows);
    revision.value++;
  }

  Future<List<ContentArtistTag>> restoreForContent({
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

  Future<Map<String, List<ContentArtistTag>>> restoreForContents({
    required ProfileContentType contentType,
    required Iterable<String> contentIds,
  }) async {
    final ids = contentIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    final rows = await _restoreRows();
    final grouped = <String, List<ContentArtistTag>>{};
    for (final row in rows) {
      if (row.contentType != contentType || !ids.contains(row.contentId)) {
        continue;
      }
      grouped.putIfAbsent(row.contentId, () => []).add(row);
    }
    return grouped;
  }

  Future<List<String>> restoreContentIdsForEntity({
    required ProfileContentType contentType,
    required String entityId,
  }) async {
    if (entityId.trim().isEmpty) return const [];
    final rows = await _restoreRows();
    return rows
        .where(
          (row) => row.contentType == contentType && row.entityId == entityId,
        )
        .map((row) => row.contentId)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> submitEntitySuggestion({
    required String name,
    required KpopEntityType type,
  }) async {
    // Local beta fallback: keep this as a no-op until suggestions sync to backend.
    debugPrint('ARTIST_SUGGESTION_LOCAL ${type.key} $name');
  }

  Future<void> submitDetailedEntitySuggestion(
    ArtistSuggestionDraft draft,
  ) async {
    await submitEntitySuggestion(
      name: draft.name,
      type: draft.type.catalogType,
    );
  }

  Future<ArtistSuggestionAdminData> restoreAdminEntitySuggestions({
    String status = 'pending',
    String type = 'all',
    String query = '',
  }) async {
    return const ArtistSuggestionAdminData(entries: []);
  }

  Future<void> updateEntitySuggestion({
    required String id,
    required ArtistSuggestionStatus status,
    String? name,
    KpopEntitySuggestionType? type,
    String? adminNotes,
  }) async {}

  List<KpopEntity> _uniqueEntities(Iterable<KpopEntity> entities) {
    final seen = <String>{};
    final result = <KpopEntity>[];
    for (final entity in entities) {
      if (entity.id.trim().isEmpty) continue;
      if (!seen.add(entity.id)) continue;
      result.add(entity);
    }
    return result;
  }

  Future<List<ContentArtistTag>> _restoreRows() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_tagsKey);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .whereType<ContentArtistTag>()
          .toList();
    } catch (_) {
      await preferences.remove(_tagsKey);
      return [];
    }
  }

  Future<void> _saveRows(List<ContentArtistTag> rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _tagsKey,
      jsonEncode(rows.map(_toJson).toList()),
    );
  }

  ContentArtistTag? _fromJson(Map<String, dynamic> json) {
    final contentType = ProfileContentType.fromKey(
      json['contentType'] as String? ?? '',
    );
    if (contentType == null) return null;
    final entityJson = (json['entity'] as Map?)?.cast<String, dynamic>();
    return ContentArtistTag(
      contentType: contentType,
      contentId: json['contentId'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      taggedBy: json['taggedBy'] as String? ?? 'local-user',
      entity: entityJson == null ? null : _entityFromJson(entityJson),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> _toJson(ContentArtistTag row) {
    return {
      'contentType': row.contentType.key,
      'contentId': row.contentId,
      'entityId': row.entityId,
      'taggedBy': row.taggedBy,
      'entity': row.entity == null ? null : _entityToJson(row.entity!),
      'createdAt': row.createdAt?.toIso8601String(),
    };
  }

  KpopEntity _entityFromJson(Map<String, dynamic> json) {
    return KpopEntity(
      id: json['id'] as String? ?? '',
      type: KpopEntityType.fromKey(json['type'] as String? ?? 'artist'),
      name: json['name'] as String? ?? 'Artista',
      normalizedName: json['normalizedName'] as String? ?? '',
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      bio: json['bio'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      imageAsset: json['imageAsset'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _entityToJson(KpopEntity entity) {
    return {
      'id': entity.id,
      'type': entity.type.key,
      'name': entity.name,
      'normalizedName': entity.normalizedName,
      'aliases': entity.aliases,
      'bio': entity.bio,
      'imageUrl': entity.imageUrl,
      'imageAsset': entity.imageAsset,
      'verified': entity.verified,
    };
  }
}

String normalizeKpopEntityName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool isExactKpopEntityDuplicate({
  required KpopEntity entity,
  required String requestedName,
  required KpopEntityType requestedType,
}) {
  final normalized = normalizeKpopEntityName(requestedName);
  if (normalized.isEmpty) return false;
  final sameKind = requestedType == KpopEntityType.group
      ? entity.type == KpopEntityType.group
      : entity.type != KpopEntityType.group;
  return sameKind &&
      [
        entity.name,
        entity.normalizedName,
        ...entity.aliases,
      ].any((name) => normalizeKpopEntityName(name) == normalized);
}

List<KpopEntity> _localEntities() {
  final entities = <KpopEntity>[];
  for (final group in discoverGroups) {
    entities.add(
      KpopEntity(
        id: group.id,
        type: KpopEntityType.group,
        name: group.name,
        normalizedName: _normalize(group.name),
        aliases: group.aliases,
        bio: group.fullBio.isEmpty ? group.bio : group.fullBio,
        imageAsset: group.imageAsset,
        imageUrl: group.imageUrl,
        verified: group.status == DiscoverEntityStatus.verified,
      ),
    );
    for (final idol in group.idols) {
      entities.add(
        KpopEntity(
          id: idol.id,
          type: KpopEntityType.idol,
          name: idol.name,
          normalizedName: _normalize(idol.name),
          aliases: [
            ...idol.aliases,
            if (idol.realName.isNotEmpty) idol.realName,
          ],
          bio: idol.fullBio.isEmpty ? idol.bio : idol.fullBio,
          imageAsset: idol.imageAsset,
          imageUrl: idol.imageUrl,
          verified: true,
        ),
      );
    }
  }
  return entities;
}

/// Catálogo editorial incluido en la app para completar fichas cuando una
/// entidad todavía no fue creada en Supabase.
List<KpopEntity> localKpopEntityCatalog() => _localEntities();

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
