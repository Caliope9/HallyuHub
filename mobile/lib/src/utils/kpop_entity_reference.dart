import '../models.dart';
import '../services/local_artist_tag_service.dart';

String kpopEntityReferenceKey(String value) {
  return value.trim().toLowerCase().replaceAll(
    RegExp(r'''[\s._\-–—/\\·'"()]+'''),
    '',
  );
}

Set<String> kpopEntityReferenceKeys(KpopEntity entity) {
  return <String>{
    kpopEntityReferenceKey(entity.id),
    kpopEntityReferenceKey(entity.name),
    kpopEntityReferenceKey(entity.normalizedName),
    ...entity.aliases.map(kpopEntityReferenceKey),
  }..remove('');
}

/// Compara la identidad de dos entidades sin confundir integrantes que
/// comparten un alias de grupo. Una coincidencia entre dos aliases, por sí
/// sola, no alcanza para afirmar que son la misma entidad.
bool kpopEntitiesShareIdentity(KpopEntity first, KpopEntity second) {
  if (first.id.trim().isNotEmpty && first.id.trim() == second.id.trim()) {
    return true;
  }

  final firstPrimaryKeys = _primaryEntityKeys(first);
  final secondPrimaryKeys = _primaryEntityKeys(second);
  if (firstPrimaryKeys.any(secondPrimaryKeys.contains)) return true;

  final firstAliasKeys = first.aliases
      .map(kpopEntityReferenceKey)
      .where((value) => value.isNotEmpty)
      .toSet();
  final secondAliasKeys = second.aliases
      .map(kpopEntityReferenceKey)
      .where((value) => value.isNotEmpty)
      .toSet();
  return firstPrimaryKeys.any(secondAliasKeys.contains) ||
      secondPrimaryKeys.any(firstAliasKeys.contains);
}

Set<String> _primaryEntityKeys(KpopEntity entity) {
  return <String>{
    kpopEntityReferenceKey(entity.id),
    kpopEntityReferenceKey(entity.name),
    kpopEntityReferenceKey(entity.normalizedName),
  }..remove('');
}

bool kpopEntityMatchesReference(
  KpopEntity entity, {
  String id = '',
  String name = '',
  Iterable<String> aliases = const <String>[],
}) {
  if (id.trim().isNotEmpty && entity.id == id.trim()) return true;
  final referenceKeys = <String>{
    kpopEntityReferenceKey(id),
    kpopEntityReferenceKey(name),
    ...aliases.map(kpopEntityReferenceKey),
  }..remove('');
  if (referenceKeys.isEmpty) return false;
  final entityKeys = kpopEntityReferenceKeys(entity);
  return referenceKeys.any(entityKeys.contains);
}

Future<KpopEntity?> resolveKpopEntityReference({
  required LocalArtistTagService artistTagService,
  String id = '',
  String name = '',
  Iterable<String> aliases = const <String>[],
  Iterable<KpopEntity> knownEntities = const <KpopEntity>[],
  bool allowLocalFallback = true,
}) async {
  final knownMatch = _bestReferenceMatch(
    knownEntities,
    id: id,
    name: name,
    aliases: aliases,
  );
  if (knownMatch != null) return knownMatch;

  final queries = <String>{
    name.trim(),
    ...aliases.map((alias) => alias.trim()),
    id.trim(),
  }..remove('');
  final candidates = <String, KpopEntity>{};
  for (final query in queries.take(4)) {
    try {
      final results = await artistTagService.searchEntities(
        query: query,
        limit: 50,
      );
      for (final entity in results) {
        if (_referenceScore(entity, id: id, name: name, aliases: aliases) > 0) {
          candidates[entity.id] = entity;
        }
      }
    } catch (_) {
      // La ficha local sigue disponible aunque falle la búsqueda remota.
    }
  }
  final remoteMatch = _bestReferenceMatch(
    candidates.values,
    id: id,
    name: name,
    aliases: aliases,
  );
  if (remoteMatch != null) return remoteMatch;
  if (!allowLocalFallback) return null;

  final localMatch = _bestReferenceMatch(
    localKpopEntityCatalog(),
    id: id,
    name: name,
    aliases: aliases,
  );
  return localMatch == null ? null : _withoutDemoVisual(localMatch);
}

KpopEntity? _bestReferenceMatch(
  Iterable<KpopEntity> entities, {
  required String id,
  required String name,
  required Iterable<String> aliases,
}) {
  KpopEntity? best;
  var bestScore = 0;
  var tied = false;
  for (final entity in entities) {
    final score = _referenceScore(entity, id: id, name: name, aliases: aliases);
    if (score > bestScore) {
      best = entity;
      bestScore = score;
      tied = false;
    } else if (score > 0 && score == bestScore && entity.id != best?.id) {
      tied = true;
    }
  }
  return bestScore > 0 && !tied ? best : null;
}

int _referenceScore(
  KpopEntity entity, {
  required String id,
  required String name,
  required Iterable<String> aliases,
}) {
  final rawId = id.trim();
  if (rawId.isNotEmpty && entity.id == rawId) return 120;

  final idKey = kpopEntityReferenceKey(rawId);
  final nameKey = kpopEntityReferenceKey(name);
  final aliasKeys = aliases
      .map(kpopEntityReferenceKey)
      .where((value) => value.isNotEmpty);
  final entityIdKey = kpopEntityReferenceKey(entity.id);
  final entityNameKeys = <String>{
    kpopEntityReferenceKey(entity.name),
    kpopEntityReferenceKey(entity.normalizedName),
  }..remove('');
  final entityAliasKeys = entity.aliases
      .map(kpopEntityReferenceKey)
      .where((value) => value.isNotEmpty)
      .toSet();

  if (idKey.isNotEmpty && idKey == entityIdKey) return 115;
  if (nameKey.isNotEmpty && entityNameKeys.contains(nameKey)) return 110;
  if (idKey.isNotEmpty && entityNameKeys.contains(idKey)) return 105;
  if (aliasKeys.any(entityNameKeys.contains)) return 100;
  if (nameKey.isNotEmpty && entityAliasKeys.contains(nameKey)) return 90;
  if (idKey.isNotEmpty && entityAliasKeys.contains(idKey)) return 85;
  if (aliasKeys.any(entityAliasKeys.contains)) return 80;
  return 0;
}

KpopEntity _withoutDemoVisual(KpopEntity entity) {
  final asset = entity.imageAsset.trim();
  if (!asset.startsWith('assets/demo-')) return entity;
  return KpopEntity(
    id: entity.id,
    type: entity.type,
    name: entity.name,
    normalizedName: entity.normalizedName,
    aliases: entity.aliases,
    bio: entity.bio,
    imageUrl: entity.imageUrl,
    verified: entity.verified,
  );
}
