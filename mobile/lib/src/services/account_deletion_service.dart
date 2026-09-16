import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

enum AccountDeletionStatus { pending, inReview, completed, canceled }

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.reviewedAt,
    required this.completedAt,
    required this.canceledAt,
    required this.requestedScope,
    required this.exportRequested,
    this.recoverableUntil,
  });

  final String id;
  final AccountDeletionStatus status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;
  final String requestedScope;
  final bool exportRequested;
  final DateTime? recoverableUntil;

  bool get canCancel => (status == AccountDeletionStatus.pending ||
          status == AccountDeletionStatus.inReview) &&
      recoverableUntil != null && recoverableUntil!.isAfter(DateTime.now());
  bool get isRecoverable => canCancel;
}

abstract class AccountDeletionService {
  Future<AccountDeletionRequest?> getStatus();

  Future<AccountDeletionRequest> request({
    String reason = '',
    bool exportRequested = false,
  });

  Future<AccountDeletionRequest> cancel(String requestId);
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;
}

class LocalAccountDeletionService implements AccountDeletionService {
  const LocalAccountDeletionService();

  static const _key = 'hallyuhub.account-deletion.v1';

  @override
  Future<AccountDeletionRequest?> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == null ? null : _localFromJson(jsonDecode(raw));
  }

  @override
  Future<AccountDeletionRequest> request({
    String reason = '',
    bool exportRequested = false,
  }) async {
    final now = DateTime.now().toUtc();
    final request = AccountDeletionRequest(
      id: 'local-deletion-${now.microsecondsSinceEpoch}',
      status: AccountDeletionStatus.pending,
      requestedAt: now,
      reviewedAt: null,
      completedAt: null,
      canceledAt: null,
      requestedScope: reason.trim(),
      exportRequested: exportRequested,
      recoverableUntil: now.add(const Duration(days: 30)),
    );
    await _write(request);
    return request;
  }

  @override
  Future<AccountDeletionRequest> cancel(String requestId) async {
    final request = await getStatus();
    if (request == null || request.id != requestId || !request.canCancel) {
      throw const AccountDeletionException('La solicitud ya no se puede reactivar.');
    }
    final canceled = AccountDeletionRequest(
      id: request.id, status: AccountDeletionStatus.canceled,
      requestedAt: request.requestedAt, reviewedAt: request.reviewedAt,
      completedAt: null, canceledAt: DateTime.now().toUtc(),
      requestedScope: request.requestedScope, exportRequested: request.exportRequested,
      recoverableUntil: request.recoverableUntil,
    );
    await _write(canceled);
    return canceled;
  }

  Future<void> _write(AccountDeletionRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'id': request.id, 'status': request.status.name,
      'requested_at': request.requestedAt.toIso8601String(),
      'canceled_at': request.canceledAt?.toIso8601String(),
      'requested_scope': request.requestedScope,
      'export_requested': request.exportRequested,
      'recoverable_until': request.recoverableUntil?.toIso8601String(),
    }));
  }

  AccountDeletionRequest _localFromJson(dynamic value) {
    final row = Map<String, dynamic>.from(value as Map);
    final requested = DateTime.parse(row['requested_at'] as String);
    return AccountDeletionRequest(
      id: row['id'] as String, status: row['status'] == 'canceled'
          ? AccountDeletionStatus.canceled : AccountDeletionStatus.pending,
      requestedAt: requested, reviewedAt: null, completedAt: null,
      canceledAt: row['canceled_at'] == null ? null : DateTime.parse(row['canceled_at'] as String),
      requestedScope: row['requested_scope'] as String? ?? '',
      exportRequested: row['export_requested'] == true,
      recoverableUntil: row['recoverable_until'] == null ? requested.add(const Duration(days: 30)) : DateTime.parse(row['recoverable_until'] as String),
    );
  }
}

class SupabaseAccountDeletionService implements AccountDeletionService {
  SupabaseAccountDeletionService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  Future<AccountDeletionRequest?> getStatus() async {
    try {
      final response = await _client.rpc('hallyu_get_account_deletion_status');
      final rows = _rows(response);
      return rows.isEmpty ? null : _fromRow(rows.first);
    } catch (error) {
      debugPrint('ACCOUNT_DELETION_STATUS_ERROR error=$error');
      throw _friendlyError(error);
    }
  }

  @override
  Future<AccountDeletionRequest> request({
    String reason = '',
    bool exportRequested = false,
  }) async {
    try {
      final response = await _client.rpc(
        'hallyu_request_account_deletion',
        params: {
          'p_reason': reason.trim(),
          'p_export_requested': exportRequested,
        },
      );
      final rows = _rows(response);
      if (rows.isEmpty) {
        throw const AccountDeletionException('Respuesta vacía.');
      }
      return _fromRow(rows.first);
    } catch (error) {
      debugPrint('ACCOUNT_DELETION_REQUEST_ERROR error=$error');
      throw _friendlyError(error);
    }
  }

  @override
  Future<AccountDeletionRequest> cancel(String requestId) async {
    try {
      final response = await _client.rpc(
        'hallyu_cancel_account_deletion',
        params: {'p_request_id': requestId},
      );
      final rows = _rows(response);
      if (rows.isEmpty) {
        throw const AccountDeletionException('Solicitud no cancelable.');
      }
      final row = rows.first;
      final status = _status(row['status']);
      final canceledAt = _date(row['canceled_at']) ?? DateTime.now().toUtc();
      return AccountDeletionRequest(
        id: _string(row['id']),
        status: status,
        requestedAt: _date(row['requested_at']) ?? canceledAt,
        reviewedAt: _date(row['reviewed_at']),
        completedAt: _date(row['completed_at']),
        canceledAt: canceledAt,
        requestedScope: _string(row['requested_scope']),
        exportRequested: row['export_requested'] == true,
        recoverableUntil: _date(row['recoverable_until']),
      );
    } catch (error) {
      debugPrint('ACCOUNT_DELETION_CANCEL_ERROR error=$error');
      throw _friendlyError(error);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    if (response is Map) return [Map<String, dynamic>.from(response)];
    return const [];
  }

  AccountDeletionRequest _fromRow(Map<String, dynamic> row) {
    return AccountDeletionRequest(
      id: _string(row['id']),
      status: _status(row['status']),
      requestedAt: _date(row['requested_at']) ?? DateTime.now().toUtc(),
      reviewedAt: _date(row['reviewed_at']),
      completedAt: _date(row['completed_at']),
      canceledAt: _date(row['canceled_at']),
      requestedScope: _string(row['requested_scope']),
      exportRequested: row['export_requested'] == true,
      recoverableUntil: _date(row['recoverable_until']),
    );
  }

  AccountDeletionStatus _status(dynamic value) {
    return switch (value?.toString()) {
      'pending' => AccountDeletionStatus.pending,
      'in_review' => AccountDeletionStatus.inReview,
      'completed' => AccountDeletionStatus.completed,
      'canceled' => AccountDeletionStatus.canceled,
      _ => throw const AccountDeletionException(
        'Estado de eliminación inválido.',
      ),
    };
  }

  String _string(dynamic value) => value?.toString() ?? '';

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  AccountDeletionException _friendlyError(Object error) {
    if (error is AccountDeletionException) return error;
    return const AccountDeletionException(
      'No pudimos procesar la solicitud. Intentá nuevamente.',
    );
  }
}
