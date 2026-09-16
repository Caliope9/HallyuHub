import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class ContentReport {
  const ContentReport({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.reportedUserId,
    required this.reporterId,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewerId,
    required this.resolutionAction,
    required this.resolutionNote,
  });

  final String id;
  final String contentType;
  final String contentId;
  final String reportedUserId;
  final String reporterId;
  final String reason;
  final String details;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String reviewerId;
  final String resolutionAction;
  final String resolutionNote;
}

abstract class ContentModerationService {
  Future<List<ContentReport>> listReports({String status = 'all'});

  Future<ContentReport> updateReport({
    required String id,
    required String status,
    String resolutionAction = '',
    String resolutionNote = '',
  });

  Future<ContentReport> hideContent({
    required ContentReport report,
    String reason = '',
  });

  Future<bool> isPubliclyVisible(ContentReport report);
}

class ContentModerationException implements Exception {
  const ContentModerationException(this.message);

  final String message;
}

class LocalContentModerationService implements ContentModerationService {
  const LocalContentModerationService();

  @override
  Future<List<ContentReport>> listReports({String status = 'all'}) async {
    throw const ContentModerationException(
      'La moderación requiere conexión con Supabase.',
    );
  }

  @override
  Future<ContentReport> updateReport({
    required String id,
    required String status,
    String resolutionAction = '',
    String resolutionNote = '',
  }) async {
    throw const ContentModerationException(
      'La moderación requiere conexión con Supabase.',
    );
  }

  @override
  Future<ContentReport> hideContent({
    required ContentReport report,
    String reason = '',
  }) async {
    throw const ContentModerationException(
      'La moderación requiere conexión con Supabase.',
    );
  }

  @override
  Future<bool> isPubliclyVisible(ContentReport report) async {
    throw const ContentModerationException(
      'La moderación requiere conexión con Supabase.',
    );
  }
}

/// Prevents the Admin panel from presenting local/demo data as a real inbox.
class UnavailableContentModerationService implements ContentModerationService {
  const UnavailableContentModerationService();

  static const _message =
      'Las herramientas de administración requieren conexión con Supabase.';

  @override
  Future<List<ContentReport>> listReports({String status = 'all'}) async {
    throw const ContentModerationException(_message);
  }

  @override
  Future<ContentReport> updateReport({
    required String id,
    required String status,
    String resolutionAction = '',
    String resolutionNote = '',
  }) async {
    throw const ContentModerationException(_message);
  }

  @override
  Future<ContentReport> hideContent({
    required ContentReport report,
    String reason = '',
  }) async {
    throw const ContentModerationException(_message);
  }

  @override
  Future<bool> isPubliclyVisible(ContentReport report) async {
    throw const ContentModerationException(_message);
  }
}

class SupabaseContentModerationService implements ContentModerationService {
  SupabaseContentModerationService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  static const _select =
      'id,content_type,content_id,reported_user_id,reporter_id,reason,'
      'details,status,created_at,reviewed_at,reviewer_id,resolution_action,'
      'resolution_note';

  @override
  Future<List<ContentReport>> listReports({String status = 'all'}) async {
    final sessionUserId = _client.auth.currentUser?.id;
    debugPrint(
      'CONTENT_MODERATION_LIST_START service=SupabaseContentModerationService '
      'user_id=${sessionUserId ?? 'none'} '
      'has_session=${_client.auth.currentSession != null} status=$status',
    );
    if (_client.auth.currentSession == null || sessionUserId == null) {
      throw const ContentModerationException(
        'No hay una sesión autenticada para cargar las denuncias.',
      );
    }
    try {
      dynamic request = _client.from('content_reports').select(_select);
      if (status != 'all') request = request.eq('status', status);
      final rows = await request.order('created_at', ascending: false);
      debugPrint('CONTENT_MODERATION_LIST_ROWS count=${rows.length}');

      final reports = <ContentReport>[];
      var invalidRows = 0;
      for (var index = 0; index < rows.length; index++) {
        final rawRow = rows[index];
        if (rawRow is! Map) {
          invalidRows++;
          debugPrint(
            'CONTENT_MODERATION_ROW_PARSE_ERROR index=$index '
            'field=row_type value_type=${rawRow.runtimeType}',
          );
          continue;
        }
        try {
          reports.add(_fromRow(Map<String, dynamic>.from(rawRow)));
        } catch (error) {
          invalidRows++;
          debugPrint(
            'CONTENT_MODERATION_ROW_PARSE_ERROR index=$index '
            'fields=${rawRow.keys.join(',')} error=$error',
          );
        }
      }
      debugPrint(
        'CONTENT_MODERATION_LIST_PARSED valid=${reports.length} '
        'invalid=$invalidRows',
      );
      if (rows.isNotEmpty && reports.isEmpty) {
        throw const ContentModerationException(
          'Las denuncias llegaron con un formato inválido.',
        );
      }
      return reports;
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'CONTENT_MODERATION_LIST_POSTGREST_ERROR '
        'code=${error.code} message=${error.message} details=${error.details}',
      );
      throw const ContentModerationException(
        'No pudimos cargar las denuncias. Revisá permisos o conexión.',
      );
    } on ContentModerationException {
      rethrow;
    } catch (error) {
      debugPrint('CONTENT_MODERATION_LIST_ERROR error=$error');
      throw const ContentModerationException(
        'No pudimos cargar las denuncias. Revisá permisos o conexión.',
      );
    }
  }

  @override
  Future<ContentReport> updateReport({
    required String id,
    required String status,
    String resolutionAction = '',
    String resolutionNote = '',
  }) async {
    if (!const {
      'pending',
      'reviewing',
      'resolved',
      'dismissed',
    }.contains(status)) {
      throw const ContentModerationException('Estado de reporte inválido.');
    }
    try {
      final row = await _client
          .from('content_reports')
          .update({
            'status': status,
            'reviewer_id': _client.auth.currentUser?.id,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'resolution_action': resolutionAction.trim().isEmpty
                ? null
                : resolutionAction.trim(),
            'resolution_note': resolutionNote.trim(),
          })
          .eq('id', id)
          .select(_select)
          .single();
      return _fromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('CONTENT_MODERATION_UPDATE_ERROR id=$id error=$error');
      throw const ContentModerationException(
        'No pudimos actualizar la denuncia. Revisá permisos o conexión.',
      );
    }
  }

  @override
  Future<ContentReport> hideContent({
    required ContentReport report,
    String reason = '',
  }) async {
    final contentId = report.contentId.trim();
    if (!_looksLikeUuid(contentId)) {
      throw const ContentModerationException(
        'La denuncia no tiene un identificador de contenido válido.',
      );
    }
    const allowedStatuses = {'pending', 'reviewing'};
    if (!allowedStatuses.contains(report.status.trim().toLowerCase())) {
      throw const ContentModerationException(
        'Solo se pueden ocultar denuncias pendientes o en revisión.',
      );
    }

    try {
      // Keep the table allow-list explicit. RLS decides whether this caller
      // has the admin/moderator update permission for the target row.
      switch (report.contentType.trim().toLowerCase()) {
        case 'post':
          await _client
              .from('posts')
              .update({
                'status': 'deleted',
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', contentId);
        case 'drop':
          await _client
              .from('drops')
              .update({
                'status': 'deleted',
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', contentId);
        case 'fancam':
          await _client
              .from('fancams')
              .update({
                'status': 'deleted',
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', contentId);
        case 'comment':
          await _client
              .from('comments')
              .update({
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', contentId);
        case 'drop_comment':
          await _client
              .from('drop_comments')
              .update({
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', contentId);
        case 'fancam_comment':
          await _client
              .from('fancam_comments')
              .update({
                'deleted_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', contentId);
        case 'story':
          final now = DateTime.now().toUtc().toIso8601String();
          await _client
              .from('stories')
              .update({
                'deleted_at': now,
                'archived_at': now,
                'expires_at': now,
                'updated_at': now,
              })
              .eq('id', contentId);
        default:
          throw const ContentModerationException(
            'Este tipo de contenido todavía no admite ocultamiento seguro.',
          );
      }

      if (await isPubliclyVisible(report)) {
        throw const ContentModerationException(
          'El contenido sigue visible; la denuncia no fue resuelta.',
        );
      }

      final updated = await updateReport(
        id: report.id,
        status: 'resolved',
        resolutionAction: 'hidden',
        resolutionNote: reason.trim().isEmpty
            ? 'Contenido ocultado por moderación.'
            : reason.trim(),
      );
      debugPrint(
        'CONTENT_MODERATION_HIDE_OK type=${report.contentType} content=$contentId report=${report.id}',
      );
      return updated;
    } on ContentModerationException {
      rethrow;
    } catch (error) {
      debugPrint(
        'CONTENT_MODERATION_HIDE_ERROR type=${report.contentType} content=$contentId error=$error',
      );
      throw const ContentModerationException(
        'No pudimos ocultar el contenido. Revisá permisos o conexión.',
      );
    }
  }

  @override
  Future<bool> isPubliclyVisible(ContentReport report) async {
    final contentId = report.contentId.trim();
    if (!_looksLikeUuid(contentId)) return false;
    try {
      final rows = switch (report.contentType.trim().toLowerCase()) {
        'post' =>
          await _client
              .from('posts')
              .select('id')
              .eq('id', contentId)
              .eq('status', 'published')
              .filter('deleted_at', 'is', null),
        'drop' =>
          await _client
              .from('drops')
              .select('id')
              .eq('id', contentId)
              .eq('status', 'published')
              .filter('deleted_at', 'is', null),
        'fancam' =>
          await _client
              .from('fancams')
              .select('id')
              .eq('id', contentId)
              .eq('status', 'published')
              .filter('deleted_at', 'is', null),
        'comment' || 'drop_comment' || 'fancam_comment' =>
          await _client
              .from(switch (report.contentType.trim().toLowerCase()) {
                'comment' => 'comments',
                'drop_comment' => 'drop_comments',
                _ => 'fancam_comments',
              })
              .select('id')
              .eq('id', contentId)
              .filter('deleted_at', 'is', null),
        'story' =>
          await _client
              .from('stories')
              .select('id')
              .eq('id', contentId)
              .gt('expires_at', DateTime.now().toUtc().toIso8601String())
              .filter('deleted_at', 'is', null),
        _ => const <Map<String, dynamic>>[],
      };
      return rows.isNotEmpty;
    } catch (error) {
      debugPrint(
        'CONTENT_MODERATION_VERIFY_ERROR type=${report.contentType} content=$contentId error=$error',
      );
      throw const ContentModerationException(
        'No pudimos verificar la visibilidad del contenido.',
      );
    }
  }

  ContentReport _fromRow(Map<String, dynamic> row) {
    return ContentReport(
      id: _text(row['id']),
      contentType: _text(row['content_type']),
      contentId: _text(row['content_id']),
      reportedUserId: _text(row['reported_user_id']),
      reporterId: _text(row['reporter_id']),
      reason: _text(row['reason']),
      details: _text(row['details']),
      status: _text(row['status']),
      createdAt: DateTime.tryParse(_text(row['created_at'])) ?? DateTime.now(),
      reviewedAt: DateTime.tryParse(_text(row['reviewed_at'])),
      reviewerId: _text(row['reviewer_id']),
      resolutionAction: _text(row['resolution_action']),
      resolutionNote: _text(row['resolution_note']),
    );
  }

  String _text(dynamic value) => value?.toString() ?? '';

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
