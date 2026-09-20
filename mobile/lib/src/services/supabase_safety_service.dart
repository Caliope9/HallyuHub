import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'local_safety_service.dart';

class SupabaseSafetyService extends LocalSafetyService {
  SupabaseSafetyService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealSafety => true;

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> reportContent({
    required String contentType,
    String contentId = '',
    String reportedUserId = '',
    required String reason,
    String details = '',
    Map<String, Object?> metadata = const {},
  }) async {
    final reporterId = _requireUser();
    if (reportedUserId == reporterId && contentType == 'profile') {
      throw const SafetyServiceException('No podés reportar tu propio perfil.');
    }
    try {
      final reportMetadata = <String, Object?>{
        ...metadata,
        if (reason == 'child_safety') ...{
          'safety_category': 'child_safety',
          'severity': 'critical',
          'priority': 'urgent',
          'requires_immediate_review': true,
        },
      };
      await _client.from('content_reports').insert({
        'reporter_id': reporterId,
        'reported_user_id': _uuidOrNull(reportedUserId),
        'content_type': contentType,
        'content_id': _uuidOrNull(contentId),
        'reason': reason,
        'details': details.trim(),
        'status': 'pending',
        'metadata': reportMetadata,
      });
      debugPrint(
        'SAFETY_REPORT_OK type=$contentType content=$contentId reported=$reportedUserId',
      );
    } catch (error) {
      debugPrint(
        'SAFETY_REPORT_ERROR type=$contentType content=$contentId error=$error',
      );
      throw _safetyError(
        error,
        fallback:
            'No pudimos guardar el reporte. Probá de nuevo en unos segundos.',
      );
    }
  }

  @override
  Future<Set<String>> restoreBlockedUserIds() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return <String>{};
    try {
      final rows = await _client
          .from('user_blocks')
          .select('blocker_id,blocked_id')
          .or('blocker_id.eq.$currentUserId,blocked_id.eq.$currentUserId');
      final ids = <String>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final blocker = row['blocker_id'] as String? ?? '';
        final blocked = row['blocked_id'] as String? ?? '';
        if (blocker == currentUserId && blocked.isNotEmpty) ids.add(blocked);
        if (blocked == currentUserId && blocker.isNotEmpty) ids.add(blocker);
      }
      return ids;
    } catch (error) {
      debugPrint('SAFETY_BLOCK_RESTORE_ERROR $error');
      throw _safetyError(
        error,
        fallback: 'No pudimos cargar bloqueos de seguridad.',
      );
    }
  }

  @override
  Future<bool> hasBlockedUser(String userId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || userId.isEmpty) return false;
    final rows = await _client
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', currentUserId)
        .eq('blocked_id', userId)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> isInteractionBlocked(String userId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || userId.isEmpty) return false;
    final rows = await _client
        .from('user_blocks')
        .select('blocker_id,blocked_id')
        .or(
          'and(blocker_id.eq.$currentUserId,blocked_id.eq.$userId),'
          'and(blocker_id.eq.$userId,blocked_id.eq.$currentUserId)',
        )
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> blockUser(String userId) async {
    final currentUserId = _requireUser();
    if (userId.trim().isEmpty) {
      throw const SafetyServiceException('No se encontró el usuario.');
    }
    if (userId == currentUserId) {
      throw const SafetyServiceException('No podés bloquearte a vos.');
    }
    try {
      await _client.from('user_blocks').upsert({
        'blocker_id': currentUserId,
        'blocked_id': userId,
      }, onConflict: 'blocker_id,blocked_id');
      LocalSafetyService.revision.value++;
    } catch (error) {
      debugPrint('SAFETY_BLOCK_ERROR target=$userId error=$error');
      throw _safetyError(
        error,
        fallback: 'No pudimos bloquear este usuario. Probá de nuevo.',
      );
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    final currentUserId = _requireUser();
    try {
      await _client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId);
      LocalSafetyService.revision.value++;
    } catch (error) {
      debugPrint('SAFETY_UNBLOCK_ERROR target=$userId error=$error');
      throw _safetyError(
        error,
        fallback: 'No pudimos desbloquear este usuario. Probá de nuevo.',
      );
    }
  }

  String _requireUser() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw const SafetyServiceException('Necesitás iniciar sesión.');
    }
    return currentUserId;
  }

  String? _uuidOrNull(String value) {
    final clean = value.trim();
    if (_looksLikeUuid(clean)) return clean;
    return null;
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  SafetyServiceException _safetyError(
    Object error, {
    required String fallback,
  }) {
    final text = error.toString().toLowerCase();
    if (text.contains('content_reports') ||
        text.contains('user_blocks') ||
        text.contains('schema cache')) {
      return const SafetyServiceException(
        'Falta correr la migración de seguridad en Supabase.',
      );
    }
    if (text.contains('row-level security') ||
        text.contains('42501') ||
        text.contains('permission')) {
      return const SafetyServiceException(
        'No tenés permiso para completar esta acción.',
      );
    }
    if (text.contains('failed to fetch') ||
        text.contains('network') ||
        text.contains('connection')) {
      return const SafetyServiceException(
        'No pudimos conectar con el servidor.',
      );
    }
    return SafetyServiceException(fallback);
  }
}
