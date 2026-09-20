import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

enum RepostContentType { post, drop, fancam }

class RepostRecord {
  const RepostRecord({
    required this.id,
    required this.userId,
    required this.contentType,
    required this.contentId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final RepostContentType contentType;
  final String contentId;
  final DateTime createdAt;
}

class RepostServiceException implements Exception {
  const RepostServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contract shared by local previews and the backend implementation.
/// Production writes must go through the protected RPCs created by the
/// review-only migration; Flutter never writes an arbitrary repost balance or
/// copies the original media.
abstract class RepostService {
  Future<RepostRecord> createRepost({
    required RepostContentType contentType,
    required String contentId,
  });

  Future<void> removeRepost({
    required RepostContentType contentType,
    required String contentId,
  });

  Future<bool> hasReposted({
    required RepostContentType contentType,
    required String contentId,
  });
}

class LocalRepostService implements RepostService {
  final Map<String, RepostRecord> _records = {};

  @override
  Future<RepostRecord> createRepost({
    required RepostContentType contentType,
    required String contentId,
  }) async {
    final key = '${contentType.name}:$contentId';
    return _records[key] ??= RepostRecord(
      id: 'local-repost-${_records.length + 1}',
      userId: 'local-user',
      contentType: contentType,
      contentId: contentId,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeRepost({
    required RepostContentType contentType,
    required String contentId,
  }) async {
    _records.remove('${contentType.name}:$contentId');
  }

  @override
  Future<bool> hasReposted({
    required RepostContentType contentType,
    required String contentId,
  }) async => contains(contentType, contentId);

  bool contains(RepostContentType contentType, String contentId) =>
      _records.containsKey('${contentType.name}:$contentId');
}

class SupabaseRepostService implements RepostService {
  SupabaseRepostService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  Future<RepostRecord> createRepost({
    required RepostContentType contentType,
    required String contentId,
  }) async {
    if (_client.auth.currentUser == null) {
      throw const RepostServiceException('Necesitás iniciar sesión.');
    }
    try {
      final row = await _client.rpc(
        'hallyu_create_repost_v1',
        params: {'p_content_type': contentType.name, 'p_content_id': contentId},
      );
      final data = (row as Map).cast<String, dynamic>();
      return _fromRow(data);
    } catch (_) {
      throw const RepostServiceException(
        'No se pudo repostear este contenido. Puede que ya no esté disponible.',
      );
    }
  }

  @override
  Future<void> removeRepost({
    required RepostContentType contentType,
    required String contentId,
  }) async {
    if (_client.auth.currentUser == null) {
      throw const RepostServiceException('Necesitás iniciar sesión.');
    }
    try {
      await _client.rpc(
        'hallyu_remove_repost_v1',
        params: {'p_content_type': contentType.name, 'p_content_id': contentId},
      );
    } catch (_) {
      throw const RepostServiceException('No se pudo quitar el repost.');
    }
  }

  @override
  Future<bool> hasReposted({
    required RepostContentType contentType,
    required String contentId,
  }) async {
    if (_client.auth.currentUser == null) return false;
    try {
      final result = await _client.rpc(
        'hallyu_has_reposted_v1',
        params: {'p_content_type': contentType.name, 'p_content_id': contentId},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  RepostRecord _fromRow(Map<String, dynamic> row) {
    return RepostRecord(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      contentType: RepostContentType.values.byName(
        row['content_type'] as String? ?? RepostContentType.post.name,
      ),
      contentId: row['content_id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
