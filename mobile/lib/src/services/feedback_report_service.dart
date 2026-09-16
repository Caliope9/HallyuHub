import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'media_upload_limits.dart';

const feedbackProblemTypes = <FeedbackChoice>[
  FeedbackChoice('video_audio', 'Video / audio'),
  FeedbackChoice('upload', 'Subida de contenido'),
  FeedbackChoice('login', 'Login / registro'),
  FeedbackChoice('comentarios', 'Comentarios'),
  FeedbackChoice('mensajes', 'Mensajes'),
  FeedbackChoice('perfil', 'Perfil'),
  FeedbackChoice('carga_lenta', 'Carga lenta'),
  FeedbackChoice('app_se_cierra', 'La app se cierra'),
  FeedbackChoice('contenido_duplicado', 'Contenido duplicado'),
  FeedbackChoice('otro', 'Otro'),
];

const feedbackScreens = <FeedbackChoice>[
  FeedbackChoice('posts', 'Posts'),
  FeedbackChoice('drops', 'Drops'),
  FeedbackChoice('fancams', 'Fancams'),
  FeedbackChoice('stories', 'Stories'),
  FeedbackChoice('perfil', 'Perfil'),
  FeedbackChoice('mensajes', 'Mensajes'),
  FeedbackChoice('comunidades', 'Comunidades'),
  FeedbackChoice('beta_acceso', 'Acceso anticipado'),
  FeedbackChoice('otro', 'Otro'),
];

const feedbackStatuses = <FeedbackChoice>[
  FeedbackChoice('pending', 'Pendiente'),
  FeedbackChoice('reviewing', 'En revisión'),
  FeedbackChoice('resolved', 'Resuelto'),
  FeedbackChoice('not_reproducible', 'No reproducible'),
  FeedbackChoice('rejected', 'Rechazado'),
];

const feedbackPriorities = <FeedbackChoice>[
  FeedbackChoice('low', 'Baja'),
  FeedbackChoice('normal', 'Normal'),
  FeedbackChoice('high', 'Alta'),
  FeedbackChoice('urgent', 'Urgente'),
];

class FeedbackChoice {
  const FeedbackChoice(this.key, this.label);

  final String key;
  final String label;
}

class FeedbackAttachment {
  const FeedbackAttachment({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');
}

class FeedbackReportDraft {
  const FeedbackReportDraft({
    required this.type,
    required this.screen,
    required this.description,
    this.relatedContentType,
    this.relatedContentId,
    this.attachment,
  });

  final String type;
  final String screen;
  final String description;
  final String? relatedContentType;
  final String? relatedContentId;
  final FeedbackAttachment? attachment;
}

class FeedbackReportEntry {
  const FeedbackReportEntry({
    required this.id,
    required this.email,
    required this.type,
    required this.screen,
    required this.description,
    required this.status,
    required this.priority,
    required this.platform,
    required this.createdAt,
    this.userId,
    this.relatedContentType,
    this.relatedContentId,
    this.attachmentUrl,
    this.adminNotes = '',
    this.resolvedAt,
  });

  final String id;
  final String? userId;
  final String email;
  final String type;
  final String screen;
  final String description;
  final String status;
  final String priority;
  final String platform;
  final DateTime createdAt;
  final String? relatedContentType;
  final String? relatedContentId;
  final String? attachmentUrl;
  final String adminNotes;
  final DateTime? resolvedAt;
}

class FeedbackAdminData {
  const FeedbackAdminData({required this.entries});

  final List<FeedbackReportEntry> entries;

  int get total => entries.length;
  int get pending => entries.where((entry) => entry.status == 'pending').length;
  int get reviewing =>
      entries.where((entry) => entry.status == 'reviewing').length;
  int get resolved =>
      entries.where((entry) => entry.status == 'resolved').length;
  int get urgent => entries.where((entry) => entry.priority == 'urgent').length;
}

abstract class FeedbackReportService {
  const FeedbackReportService();

  bool get usesRealFeedback => false;

  Future<void> submitReport({
    required AuthUser user,
    required FeedbackReportDraft draft,
  });

  Future<FeedbackAdminData> restoreAdminReports({
    String status = 'all',
    String type = 'all',
    String screen = 'all',
    String platform = 'all',
    String priority = 'all',
    String query = '',
  });

  Future<void> updateReport({
    required String id,
    String? status,
    String? priority,
    String? adminNotes,
  });
}

class LocalFeedbackReportService extends FeedbackReportService {
  const LocalFeedbackReportService();

  static const _storageKey = 'hallyuhub.feedback.reports.v1';

  @override
  Future<void> submitReport({
    required AuthUser user,
    required FeedbackReportDraft draft,
  }) async {
    _validateDraft(draft);
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    final rows = stored == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(stored) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .toList();
    rows.add({
      'id': 'local-feedback-${DateTime.now().microsecondsSinceEpoch}',
      'email': user.email,
      'type': draft.type,
      'screen': draft.screen,
      'description': draft.description.trim(),
      'status': 'pending',
      'priority': 'normal',
      'platform': _platformLabel(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'admin_notes': '',
    });
    await preferences.setString(_storageKey, jsonEncode(rows));
  }

  @override
  Future<FeedbackAdminData> restoreAdminReports({
    String status = 'all',
    String type = 'all',
    String screen = 'all',
    String platform = 'all',
    String priority = 'all',
    String query = '',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    final rows = stored == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(stored) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .toList();
    final normalizedQuery = query.trim().toLowerCase();
    final entries = rows
        .map(_entryFromRow)
        .where((entry) {
          if (status != 'all' && entry.status != status) return false;
          if (type != 'all' && entry.type != type) return false;
          if (screen != 'all' && entry.screen != screen) return false;
          if (platform != 'all' && entry.platform != platform) return false;
          if (priority != 'all' && entry.priority != priority) return false;
          if (normalizedQuery.isEmpty) return true;
          return '${entry.email} ${entry.description} ${entry.adminNotes}'
              .toLowerCase()
              .contains(normalizedQuery);
        })
        .toList(growable: false);
    return FeedbackAdminData(entries: entries);
  }

  @override
  Future<void> updateReport({
    required String id,
    String? status,
    String? priority,
    String? adminNotes,
  }) async {}
}

class SupabaseFeedbackReportService extends FeedbackReportService {
  SupabaseFeedbackReportService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  static const _bucket = 'feedback_attachments';
  static const _appVersion = '2026-06-beta-real';

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealFeedback => true;

  @override
  Future<void> submitReport({
    required AuthUser user,
    required FeedbackReportDraft draft,
  }) async {
    _validateDraft(draft);
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const FeedbackReportException('Necesitás iniciar sesión.');
    }
    String? attachmentPath;
    try {
      if (draft.attachment != null) {
        attachmentPath = await _uploadAttachment(
          authUser.id,
          draft.attachment!,
        );
      }
      await _client.from('feedback_reports').insert({
        'user_id': authUser.id,
        'email': authUser.email ?? user.email,
        'type': draft.type,
        'screen': draft.screen,
        'description': draft.description.trim(),
        'status': 'pending',
        'priority': 'normal',
        'app_version': _appVersion,
        'platform': _platformLabel(),
        'device_info': _deviceInfo(),
        'related_content_type': draft.relatedContentType,
        'related_content_id': _uuidOrNull(draft.relatedContentId),
        'attachment_url': attachmentPath,
      });
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'FEEDBACK_SUBMIT_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw FeedbackReportException(_messageFor(error));
    } catch (error) {
      debugPrint('FEEDBACK_SUBMIT_ERROR error=$error');
      if (error is FeedbackReportException) rethrow;
      final text = error.toString().toLowerCase();
      if (text.contains('feedback_attachments') ||
          text.contains('feedback_reports') ||
          text.contains('bucket') ||
          text.contains('schema')) {
        throw const FeedbackReportException(
          'Falta completar la configuración de reportes del acceso anticipado en Supabase.',
        );
      }
      if (text.contains('row-level security') ||
          text.contains('policy') ||
          text.contains('permission')) {
        throw const FeedbackReportException(
          'No tenés permisos para completar esta acción.',
        );
      }
      throw const FeedbackReportException(
        'No pudimos enviar el reporte. Revisá conexión y probá de nuevo.',
      );
    }
  }

  @override
  Future<FeedbackAdminData> restoreAdminReports({
    String status = 'all',
    String type = 'all',
    String screen = 'all',
    String platform = 'all',
    String priority = 'all',
    String query = '',
  }) async {
    try {
      dynamic request = _client.from('feedback_reports').select();
      if (status != 'all') request = request.eq('status', status);
      if (type != 'all') request = request.eq('type', type);
      if (screen != 'all') request = request.eq('screen', screen);
      if (platform != 'all') request = request.eq('platform', platform);
      if (priority != 'all') request = request.eq('priority', priority);
      final rows = await request
          .order('created_at', ascending: false)
          .limit(500);
      final normalizedQuery = query.trim().toLowerCase();
      final entries = <FeedbackReportEntry>[];
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final entry = _entryFromRow(row);
        if (normalizedQuery.isNotEmpty &&
            !'${entry.email} ${entry.description} ${entry.adminNotes}'
                .toLowerCase()
                .contains(normalizedQuery)) {
          continue;
        }
        entries.add(await _withSignedAttachment(entry));
      }
      return FeedbackAdminData(entries: entries);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'FEEDBACK_ADMIN_FETCH_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw FeedbackReportException(_messageFor(error));
    } catch (error) {
      debugPrint('FEEDBACK_ADMIN_FETCH_ERROR error=$error');
      throw const FeedbackReportException(
        'No pudimos cargar reportes. Revisá permisos o conexión.',
      );
    }
  }

  @override
  Future<void> updateReport({
    required String id,
    String? status,
    String? priority,
    String? adminNotes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{'updated_at': now};
    if (status != null) {
      payload['status'] = status;
      payload['resolved_at'] = status == 'resolved' ? now : null;
    }
    if (priority != null) payload['priority'] = priority;
    if (adminNotes != null) payload['admin_notes'] = adminNotes;
    if (payload.length == 1) return;
    try {
      await _client.from('feedback_reports').update(payload).eq('id', id);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'FEEDBACK_ADMIN_UPDATE_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw FeedbackReportException(_messageFor(error));
    }
  }

  Future<String> _uploadAttachment(
    String userId,
    FeedbackAttachment attachment,
  ) async {
    _validateAttachment(attachment);
    final extension = _extensionForMimeType(attachment.mimeType);
    final safeName = _safeFileName(attachment.fileName, extension);
    final path =
        '$userId/feedback_${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          attachment.bytes,
          fileOptions: supabase.FileOptions(
            contentType: attachment.mimeType,
            upsert: false,
            cacheControl: '3600',
          ),
        );
    return path;
  }

  Future<FeedbackReportEntry> _withSignedAttachment(
    FeedbackReportEntry entry,
  ) async {
    final path = entry.attachmentUrl;
    if (path == null || path.isEmpty || path.startsWith('http')) return entry;
    try {
      final signed = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, 60 * 60);
      return FeedbackReportEntry(
        id: entry.id,
        userId: entry.userId,
        email: entry.email,
        type: entry.type,
        screen: entry.screen,
        description: entry.description,
        status: entry.status,
        priority: entry.priority,
        platform: entry.platform,
        createdAt: entry.createdAt,
        relatedContentType: entry.relatedContentType,
        relatedContentId: entry.relatedContentId,
        attachmentUrl: signed,
        adminNotes: entry.adminNotes,
        resolvedAt: entry.resolvedAt,
      );
    } catch (_) {
      return entry;
    }
  }

  String _messageFor(supabase.PostgrestException error) {
    final text = '${error.message} ${error.details}'.toLowerCase();
    if (error.code == '42p01' ||
        text.contains('feedback_reports') ||
        text.contains('feedback_attachments') ||
        text.contains('schema cache')) {
      return 'Falta completar la configuración de reportes del acceso anticipado en Supabase.';
    }
    if (error.code == '42501' ||
        text.contains('permission') ||
        text.contains('row-level security') ||
        text.contains('policy')) {
      return 'No tenés permisos para completar esta acción.';
    }
    return error.message;
  }
}

FeedbackReportEntry _entryFromRow(Map<String, dynamic> row) {
  return FeedbackReportEntry(
    id: _string(row['id']),
    userId: _nullableString(row['user_id']),
    email: _string(row['email']),
    type: _string(row['type'], fallback: 'otro'),
    screen: _string(row['screen'], fallback: 'otro'),
    description: _string(row['description']),
    status: _string(row['status'], fallback: 'pending'),
    priority: _string(row['priority'], fallback: 'normal'),
    platform: _string(row['platform'], fallback: 'unknown'),
    createdAt:
        _date(row['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    relatedContentType: _nullableString(row['related_content_type']),
    relatedContentId: _nullableString(row['related_content_id']),
    attachmentUrl: _nullableString(row['attachment_url']),
    adminNotes: _string(row['admin_notes']),
    resolvedAt: _date(row['resolved_at']),
  );
}

void _validateDraft(FeedbackReportDraft draft) {
  if (draft.description.trim().length < 8) {
    throw const FeedbackReportException(
      'Contanos un poco más para poder revisar el problema.',
    );
  }
  if (draft.description.trim().length > 2000) {
    throw const FeedbackReportException(
      'El reporte es demasiado largo. Resumilo en menos de 2000 caracteres.',
    );
  }
  final attachment = draft.attachment;
  if (attachment != null) _validateAttachment(attachment);
}

void _validateAttachment(FeedbackAttachment attachment) {
  if (attachment.bytes.isEmpty) {
    throw const FeedbackReportException('No pudimos leer el archivo adjunto.');
  }
  if (attachment.isImage) {
    if (attachment.bytes.lengthInBytes > MediaUploadLimits.imageBytes) {
      throw const FeedbackReportException(
        'La captura supera el límite de 10 MB.',
      );
    }
    if (MediaUploadLimits.detectImageContentType(attachment.bytes) == null) {
      throw const FeedbackReportException(
        'La captura debe ser JPG, PNG o WEBP.',
      );
    }
    return;
  }
  if (attachment.isVideo) {
    if (attachment.bytes.lengthInBytes > MediaUploadLimits.messageVideoBytes) {
      throw const FeedbackReportException(
        'El video supera el límite de 50 MB.',
      );
    }
    if (!_allowedVideoMimeTypes.contains(attachment.mimeType)) {
      throw const FeedbackReportException('El video debe ser MP4, MOV o WEBM.');
    }
    return;
  }
  throw const FeedbackReportException(
    'Adjuntá una imagen o un video corto compatible.',
  );
}

const _allowedVideoMimeTypes = {'video/mp4', 'video/quicktime', 'video/webm'};

String feedbackChoiceLabel(List<FeedbackChoice> choices, String key) {
  return choices
          .where((choice) => choice.key == key)
          .map((choice) => choice.label)
          .firstOrNull ??
      key;
}

String inferFeedbackMimeType(String fileName, String? mimeType) {
  final clean = (mimeType ?? '').trim().toLowerCase();
  if (clean.isNotEmpty && clean != 'application/octet-stream') return clean;
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  return 'application/octet-stream';
}

String _platformLabel() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}

Map<String, Object?> _deviceInfo() {
  return {
    'platform': _platformLabel(),
    'is_web': kIsWeb,
    'flutter_platform': defaultTargetPlatform.name,
  };
}

String _safeFileName(String fileName, String extension) {
  final sanitized = fileName
      .split('/')
      .last
      .split('\\')
      .last
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  if (sanitized.contains('.') && sanitized.length <= 96) return sanitized;
  return 'feedback.$extension';
}

String _extensionForMimeType(String mimeType) {
  return switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    'video/webm' => 'webm',
    _ => 'bin',
  };
}

String? _uuidOrNull(String? value) {
  final clean = (value ?? '').trim();
  if (RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(clean)) {
    return clean;
  }
  return null;
}

DateTime? _date(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _string(dynamic value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

String? _nullableString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

class FeedbackReportException implements Exception {
  const FeedbackReportException(this.message);

  final String message;

  @override
  String toString() => 'FeedbackReportException: $message';
}
