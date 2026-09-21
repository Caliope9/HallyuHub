import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class KpopEntityFollowService {
  const KpopEntityFollowService(this._client);

  final supabase.SupabaseClient _client;

  Future<int> restoreFollowerCount(String entityId) async {
    final safeId = entityId.trim();
    if (safeId.isEmpty) return 0;
    final response = await _client.rpc(
      'get_kpop_entity_follower_count',
      params: {'p_entity_id': safeId},
    );
    final row = _firstRow(response);
    return _countFrom(row?['follower_count']);
  }

  Future<Map<String, int>> restoreFollowerCounts(
    Iterable<String> entityIds,
  ) async {
    final safeIds = entityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (safeIds.isEmpty) return const {};
    final response = await _client.rpc(
      'get_kpop_entity_follower_counts',
      params: {'p_entity_ids': safeIds},
    );
    final counts = <String, int>{for (final id in safeIds) id: 0};
    for (final row in _rows(response)) {
      final id = row['entity_id']?.toString().trim() ?? '';
      if (id.isEmpty || !counts.containsKey(id)) continue;
      counts[id] = _countFrom(row['follower_count']);
    }
    return counts;
  }

  Future<void> setFollowing({
    required String entityId,
    required String userId,
    required bool following,
  }) async {
    final safeEntityId = entityId.trim();
    final safeUserId = userId.trim();
    if (safeEntityId.isEmpty || safeUserId.isEmpty) return;
    if (following) {
      await _insertIfMissing(safeEntityId, safeUserId);
      return;
    }
    await _client
        .from('kpop_entity_follows')
        .delete()
        .eq('entity_id', safeEntityId)
        .eq('user_id', safeUserId);
  }

  Future<void> replaceFollowingSelection({
    required String userId,
    required Iterable<String> currentEntityIds,
    required Iterable<String> selectedEntityIds,
  }) async {
    final safeUserId = userId.trim();
    if (safeUserId.isEmpty) return;
    final current = _cleanIds(currentEntityIds);
    final selected = _cleanIds(selectedEntityIds);
    final additions = selected.difference(current).toList(growable: false);
    final removals = current.difference(selected).toList(growable: false);
    if (additions.isEmpty && removals.isEmpty) return;

    var additionsSaved = false;
    try {
      if (additions.isNotEmpty) {
        for (final entityId in additions) {
          await _insertIfMissing(entityId, safeUserId);
        }
        additionsSaved = true;
      }
      if (removals.isNotEmpty) {
        await _client
            .from('kpop_entity_follows')
            .delete()
            .eq('user_id', safeUserId)
            .inFilter('entity_id', removals);
      }
    } catch (_) {
      if (additionsSaved) {
        try {
          await _client
              .from('kpop_entity_follows')
              .delete()
              .eq('user_id', safeUserId)
              .inFilter('entity_id', additions);
        } catch (_) {
          // The caller reloads the server state after any failed save.
        }
      }
      rethrow;
    }
  }

  Future<void> _insertIfMissing(String entityId, String userId) async {
    try {
      // Plain INSERT only needs the existing INSERT grant. A duplicate key
      // means the desired follow already exists and is therefore success.
      await _client.from('kpop_entity_follows').insert({
        'entity_id': entityId,
        'user_id': userId,
      });
    } on supabase.PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  static Set<String> _cleanIds(Iterable<String> ids) =>
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();

  static List<Map<dynamic, dynamic>> _rows(dynamic response) {
    if (response is! List) return const [];
    return response.whereType<Map>().toList(growable: false);
  }

  static Map<dynamic, dynamic>? _firstRow(dynamic response) {
    final rows = _rows(response);
    return rows.isEmpty ? null : rows.first;
  }

  static int _countFrom(dynamic value) {
    final count = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return count < 0 ? 0 : count;
  }
}
