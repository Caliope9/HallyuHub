import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyServiceException implements Exception {
  const SafetyServiceException(this.message);

  final String message;

  @override
  String toString() => 'SafetyServiceException: $message';
}

class SafetyReportReason {
  const SafetyReportReason(this.key, this.label);

  final String key;
  final String label;
}

const safetyReportReasons = <SafetyReportReason>[
  SafetyReportReason('spam', 'Spam'),
  SafetyReportReason('harassment', 'Acoso o bullying'),
  SafetyReportReason(
    'child_safety',
    'Explotación o abuso sexual infantil',
  ),
  SafetyReportReason('sexual_content', 'Contenido sexual'),
  SafetyReportReason('violence_threats', 'Violencia o amenazas'),
  SafetyReportReason('hate_discrimination', 'Odio o discriminación'),
  SafetyReportReason('scam_suspicious_sale', 'Estafa o venta sospechosa'),
  SafetyReportReason('misinformation', 'Información falsa'),
  SafetyReportReason('copyright', 'Derechos de autor'),
  SafetyReportReason('other', 'Otro'),
];

class LocalSafetyService {
  const LocalSafetyService();

  static const _blockedKey = 'hallyuhub.safety.blocked-users.v1';
  static const _reportsKey = 'hallyuhub.safety.reports.v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealSafety => false;

  Future<void> reportContent({
    required String contentType,
    String contentId = '',
    String reportedUserId = '',
    required String reason,
    String details = '',
    Map<String, Object?> metadata = const {},
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_reportsKey);
    final reports = stored == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(stored) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .toList();
    final reportMetadata = <String, Object?>{
      ...metadata,
      if (reason == 'child_safety') ...{
        'safety_category': 'child_safety',
        'severity': 'critical',
        'priority': 'urgent',
        'requires_immediate_review': true,
      },
    };
    reports.add({
      'id': 'local-report-${DateTime.now().microsecondsSinceEpoch}',
      'content_type': contentType,
      'content_id': contentId,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'details': details,
      'metadata': reportMetadata,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await preferences.setString(_reportsKey, jsonEncode(reports));
    revision.value++;
  }

  Future<Set<String>> restoreBlockedUserIds() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_blockedKey);
    return stored == null ? <String>{} : stored.toSet();
  }

  Future<bool> hasBlockedUser(String userId) async {
    final blocked = await restoreBlockedUserIds();
    return blocked.contains(userId);
  }

  Future<bool> isInteractionBlocked(String userId) => hasBlockedUser(userId);

  Future<void> blockUser(String userId) async {
    if (userId.trim().isEmpty) {
      throw const SafetyServiceException('No se encontró el usuario.');
    }
    final preferences = await SharedPreferences.getInstance();
    final blocked = await restoreBlockedUserIds();
    blocked.add(userId);
    await preferences.setStringList(_blockedKey, blocked.toList()..sort());
    revision.value++;
  }

  Future<void> unblockUser(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final blocked = await restoreBlockedUserIds();
    blocked.remove(userId);
    await preferences.setStringList(_blockedKey, blocked.toList()..sort());
    revision.value++;
  }
}
