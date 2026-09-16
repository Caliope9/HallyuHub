import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'public_access_links.dart';

enum BetaSignupStatus { approved, waiting, blocked }

extension BetaSignupStatusLabel on BetaSignupStatus {
  String get key {
    return switch (this) {
      BetaSignupStatus.approved => 'approved',
      BetaSignupStatus.waiting => 'waiting',
      BetaSignupStatus.blocked => 'blocked',
    };
  }

  String get label {
    return switch (this) {
      BetaSignupStatus.approved => 'Aprobado',
      BetaSignupStatus.waiting => 'En espera',
      BetaSignupStatus.blocked => 'Bloqueado',
    };
  }
}

class BetaSignupResult {
  const BetaSignupResult({
    required this.status,
    required this.position,
    required this.approvedCount,
    required this.betaUserLimit,
    required this.duplicate,
    this.referralCode = '',
    this.referralCount = 0,
    this.referralScore = 0,
    this.priorityScore = 0,
    this.shareUrl = '',
  });

  final BetaSignupStatus status;
  final int? position;
  final int approvedCount;
  final int betaUserLimit;
  final bool duplicate;
  final String referralCode;
  final int referralCount;
  final int referralScore;
  final int priorityScore;
  final String shareUrl;

  bool get hasShareUrl => shareUrl.trim().isNotEmpty;
}

class BetaSignupEntry {
  const BetaSignupEntry({
    required this.id,
    required this.email,
    required this.nickname,
    required this.country,
    required this.fandom,
    required this.platform,
    required this.status,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.invitedAt,
    this.adminNotes = '',
    this.referralCode = '',
    this.referredBy = '',
    this.referralCount = 0,
    this.referralScore = 0,
    this.priorityScore = 0,
    this.shareUrl = '',
  });

  final String id;
  final String email;
  final String nickname;
  final String country;
  final String fandom;
  final String platform;
  final BetaSignupStatus status;
  final int? position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? invitedAt;
  final String adminNotes;
  final String referralCode;
  final String referredBy;
  final int referralCount;
  final int referralScore;
  final int priorityScore;
  final String shareUrl;

  String get platformLabel {
    return switch (platform) {
      'android' => 'Android',
      'ios' => 'iPhone',
      _ => 'Otro',
    };
  }
}

class BetaSignupAdminData {
  const BetaSignupAdminData({required this.entries});

  final List<BetaSignupEntry> entries;

  int get total => entries.length;
  int get approved => entries
      .where((entry) => entry.status == BetaSignupStatus.approved)
      .length;
  int get waiting =>
      entries.where((entry) => entry.status == BetaSignupStatus.waiting).length;
  int get blocked =>
      entries.where((entry) => entry.status == BetaSignupStatus.blocked).length;
  int get android =>
      entries.where((entry) => entry.platform == 'android').length;
  int get ios => entries.where((entry) => entry.platform == 'ios').length;
}

abstract class BetaSignupService {
  const BetaSignupService();

  bool get usesRealBetaSignups => false;

  Future<BetaSignupResult> submit({
    required String nickname,
    required String email,
    required String country,
    required String fandom,
    required String platform,
    required bool accepted,
    String referralCode = '',
  });

  Future<BetaSignupResult?> lookupStatus({required String email});

  Future<BetaSignupAdminData> restoreAdminData({
    String status = 'all',
    String platform = 'all',
    String country = '',
    String query = '',
  });

  Future<void> updateSignup({
    required String id,
    String? status,
    String? adminNotes,
    int? priorityScore,
    bool markInvited = false,
    bool resetReferralScore = false,
  });
}

class LocalBetaSignupService extends BetaSignupService {
  const LocalBetaSignupService();

  @override
  Future<BetaSignupResult> submit({
    required String nickname,
    required String email,
    required String country,
    required String fandom,
    required String platform,
    required bool accepted,
    String referralCode = '',
  }) async {
    if (!accepted) {
      throw const BetaSignupException(
        'Necesitás aceptar participar en el acceso anticipado para anotarte.',
      );
    }
    return const BetaSignupResult(
      status: BetaSignupStatus.waiting,
      position: 1,
      approvedCount: 0,
      betaUserLimit: 100,
      duplicate: false,
      referralCode: 'hally-beta',
      referralCount: 0,
      referralScore: 0,
      priorityScore: 0,
      shareUrl: 'https://www.hallyuhub.net/acceso?ref=hally-beta',
    );
  }

  @override
  Future<BetaSignupResult?> lookupStatus({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return const BetaSignupResult(
      status: BetaSignupStatus.waiting,
      position: 1,
      approvedCount: 0,
      betaUserLimit: 100,
      duplicate: true,
      referralCode: 'hally-beta',
      referralCount: 0,
      referralScore: 0,
      priorityScore: 0,
      shareUrl: 'https://www.hallyuhub.net/acceso?ref=hally-beta',
    );
  }

  @override
  Future<BetaSignupAdminData> restoreAdminData({
    String status = 'all',
    String platform = 'all',
    String country = '',
    String query = '',
  }) async {
    return const BetaSignupAdminData(entries: []);
  }

  @override
  Future<void> updateSignup({
    required String id,
    String? status,
    String? adminNotes,
    int? priorityScore,
    bool markInvited = false,
    bool resetReferralScore = false,
  }) async {}
}

/// Keeps the public access page renderable without credentials while ensuring
/// release builds never present a simulated signup result.
class UnavailableBetaSignupService extends BetaSignupService {
  const UnavailableBetaSignupService();

  static const _message =
      'El acceso anticipado no está disponible temporalmente. Probá más tarde.';

  @override
  Future<BetaSignupResult> submit({
    required String nickname,
    required String email,
    required String country,
    required String fandom,
    required String platform,
    required bool accepted,
    String referralCode = '',
  }) async {
    throw const BetaSignupException(_message);
  }

  @override
  Future<BetaSignupResult?> lookupStatus({required String email}) async {
    throw const BetaSignupException(_message);
  }

  @override
  Future<BetaSignupAdminData> restoreAdminData({
    String status = 'all',
    String platform = 'all',
    String country = '',
    String query = '',
  }) async {
    throw const BetaSignupException(_message);
  }

  @override
  Future<void> updateSignup({
    required String id,
    String? status,
    String? adminNotes,
    int? priorityScore,
    bool markInvited = false,
    bool resetReferralScore = false,
  }) async {
    throw const BetaSignupException(_message);
  }
}

class SupabaseBetaSignupService extends BetaSignupService {
  SupabaseBetaSignupService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealBetaSignups => true;

  @override
  Future<BetaSignupResult> submit({
    required String nickname,
    required String email,
    required String country,
    required String fandom,
    required String platform,
    required bool accepted,
    String referralCode = '',
  }) async {
    if (!accepted) {
      throw const BetaSignupException(
        'Necesitás aceptar participar en el acceso anticipado para anotarte.',
      );
    }
    try {
      final params = {
        'p_email': email.trim().toLowerCase(),
        'p_nickname': nickname.trim(),
        'p_country': country.trim(),
        'p_fandom': fandom.trim(),
        'p_platform': platform.trim().toLowerCase(),
        'p_accept_beta': accepted,
        'p_referral_code': referralCode.trim(),
        'p_source': 'beta_landing',
      };
      final response = await _submitWithReferralFallback(params);
      final row = _firstRow(response);
      return _resultFromRow(row, duplicateFallback: row['duplicate'] == true);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'BETA_SIGNUP_SUBMIT_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw BetaSignupException(_messageFor(error));
    } catch (error) {
      debugPrint('BETA_SIGNUP_SUBMIT_ERROR error=$error');
      throw const BetaSignupException(
        'No pudimos enviar tu solicitud. Revisá conexión y probá de nuevo.',
      );
    }
  }

  @override
  Future<BetaSignupResult?> lookupStatus({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    try {
      final response = await _lookupWithReferralFallback(normalizedEmail);
      if (response is List && response.isEmpty) return null;
      final row = _firstRow(response);
      if (row.isEmpty) return null;
      return _resultFromRow(row, duplicateFallback: true);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'BETA_SIGNUP_LOOKUP_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw BetaSignupException(_messageFor(error));
    } catch (error) {
      debugPrint('BETA_SIGNUP_LOOKUP_ERROR error=$error');
      throw const BetaSignupException(
        'No pudimos consultar tu estado. Revisá conexión y probá de nuevo.',
      );
    }
  }

  @override
  Future<BetaSignupAdminData> restoreAdminData({
    String status = 'all',
    String platform = 'all',
    String country = '',
    String query = '',
  }) async {
    try {
      dynamic request = _client.from('beta_signups').select();
      if (status == 'approved_invited' || status == 'approved_uninvited') {
        request = request.eq('status', 'approved');
      } else if (status != 'all') {
        request = request.eq('status', status);
      }
      if (platform != 'all') request = request.eq('platform', platform);
      final rows = await request
          .order('created_at', ascending: false)
          .limit(500);
      final normalizedCountry = country.trim().toLowerCase();
      final normalizedQuery = query.trim().toLowerCase();
      final entries = rows
          .cast<Map<String, dynamic>>()
          .map(_entryFromRow)
          .where((entry) {
            if (normalizedCountry.isNotEmpty &&
                !entry.country.toLowerCase().contains(normalizedCountry)) {
              return false;
            }
            if (status == 'approved_invited' && entry.invitedAt == null) {
              return false;
            }
            if (status == 'approved_uninvited' && entry.invitedAt != null) {
              return false;
            }
            if (normalizedQuery.isEmpty) return true;
            return [
              entry.email,
              entry.nickname,
              entry.country,
              entry.fandom,
              entry.platform,
              entry.adminNotes,
              entry.referralCode,
              entry.referredBy,
            ].join(' ').toLowerCase().contains(normalizedQuery);
          })
          .toList();
      entries.sort((a, b) {
        if (status != 'waiting') return 0;
        final byPriority = b.priorityScore.compareTo(a.priorityScore);
        if (byPriority != 0) return byPriority;
        return a.createdAt.compareTo(b.createdAt);
      });
      return BetaSignupAdminData(entries: entries.toList(growable: false));
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'BETA_SIGNUP_ADMIN_FETCH_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw BetaSignupException(_messageFor(error));
    } catch (error) {
      debugPrint('BETA_SIGNUP_ADMIN_FETCH_ERROR error=$error');
      throw const BetaSignupException(
        'No pudimos cargar la lista de acceso anticipado. Revisá conexión o permisos.',
      );
    }
  }

  @override
  Future<void> updateSignup({
    required String id,
    String? status,
    String? adminNotes,
    int? priorityScore,
    bool markInvited = false,
    bool resetReferralScore = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{'updated_at': now};
    if (status != null) payload['status'] = status;
    if (adminNotes != null) payload['admin_notes'] = adminNotes;
    if (priorityScore != null) payload['priority_score'] = priorityScore;
    if (resetReferralScore) {
      payload['referral_score'] = 0;
      payload['priority_score'] = priorityScore ?? 0;
    }
    if (markInvited) payload['invited_at'] = now;
    if (payload.length == 1) return;
    try {
      await _client.from('beta_signups').update(payload).eq('id', id);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'BETA_SIGNUP_ADMIN_UPDATE_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw BetaSignupException(_messageFor(error));
    } catch (error) {
      debugPrint('BETA_SIGNUP_ADMIN_UPDATE_ERROR error=$error');
      throw const BetaSignupException(
        'No pudimos actualizar esta solicitud de acceso anticipado.',
      );
    }
  }

  Map<String, dynamic> _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final row = response.first;
      if (row is Map) return row.cast<String, dynamic>();
    }
    if (response is Map) return response.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  Future<dynamic> _submitWithReferralFallback(
    Map<String, dynamic> params,
  ) async {
    try {
      return await _client.rpc('submit_beta_signup_v2', params: params);
    } on supabase.PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      final details = error.details.toString().toLowerCase();
      if (error.code == '42883' ||
          message.contains('submit_beta_signup_v2') ||
          details.contains('submit_beta_signup_v2')) {
        final legacyParams = Map<String, dynamic>.from(params)
          ..remove('p_referral_code')
          ..remove('p_source');
        return _client.rpc('submit_beta_signup', params: legacyParams);
      }
      rethrow;
    }
  }

  Future<dynamic> _lookupWithReferralFallback(String email) async {
    try {
      return await _client.rpc(
        'get_beta_signup_status_v2',
        params: {'p_email': email},
      );
    } on supabase.PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      final details = error.details.toString().toLowerCase();
      if (error.code == '42883' ||
          message.contains('get_beta_signup_status_v2') ||
          details.contains('get_beta_signup_status_v2')) {
        return _client.rpc(
          'get_beta_signup_status',
          params: {'p_email': email},
        );
      }
      rethrow;
    }
  }

  BetaSignupResult _resultFromRow(
    Map<String, dynamic> row, {
    required bool duplicateFallback,
  }) {
    final referralCode = _string(row['referral_code']);
    return BetaSignupResult(
      status: _status(row['status']),
      position: _int(row['position']),
      approvedCount: _int(row['approved_count']) ?? 0,
      betaUserLimit: _int(row['beta_user_limit']) ?? 100,
      duplicate: row['duplicate'] == true || duplicateFallback,
      referralCode: referralCode,
      referralCount: _int(row['referral_count']) ?? 0,
      referralScore: _int(row['referral_score']) ?? 0,
      priorityScore: _int(row['priority_score']) ?? 0,
      shareUrl: canonicalPublicAccessShareUrl(
        referralCode: referralCode,
        existingUrl: _string(row['share_url']),
      ),
    );
  }

  BetaSignupEntry _entryFromRow(Map<String, dynamic> row) {
    final referralCode = _string(row['referral_code']);
    return BetaSignupEntry(
      id: _string(row['id']),
      email: _string(row['email']),
      nickname: _string(row['nickname']),
      country: _string(row['country']),
      fandom: _string(row['fandom']),
      platform: _string(row['platform'], fallback: 'other'),
      status: _status(row['status']),
      position: _int(row['position']),
      createdAt:
          _date(row['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _date(row['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      invitedAt: _date(row['invited_at']),
      adminNotes: _string(row['admin_notes']),
      referralCode: referralCode,
      referredBy: _string(row['referred_by']),
      referralCount: _int(row['referral_count']) ?? 0,
      referralScore: _int(row['referral_score']) ?? 0,
      priorityScore: _int(row['priority_score']) ?? 0,
      shareUrl: canonicalPublicAccessShareUrl(
        referralCode: referralCode,
        existingUrl: _string(row['share_url']),
      ),
    );
  }

  BetaSignupStatus _status(dynamic value) {
    return switch (_string(value, fallback: 'waiting')) {
      'approved' => BetaSignupStatus.approved,
      'blocked' => BetaSignupStatus.blocked,
      _ => BetaSignupStatus.waiting,
    };
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
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

  String _messageFor(supabase.PostgrestException error) {
    final message = error.message.toLowerCase();
    final details = error.details.toString().toLowerCase();
    if (error.code == '42883' ||
        message.contains('submit_beta_signup') ||
        message.contains('submit_beta_signup_v2') ||
        message.contains('get_beta_signup_status') ||
        details.contains('submit_beta_signup') ||
        details.contains('submit_beta_signup_v2') ||
        details.contains('get_beta_signup_status')) {
      return 'Falta completar la configuración del acceso anticipado en Supabase.';
    }
    if (error.code == '42p01' ||
        message.contains('beta_signups') ||
        details.contains('beta_signups')) {
      return 'Falta crear la tabla beta_signups en Supabase.';
    }
    if (error.code == '42501' ||
        message.contains('permission') ||
        message.contains('row-level security') ||
        message.contains('policy')) {
      return 'No tenés permisos para esta acción de acceso anticipado.';
    }
    return error.message;
  }
}

class BetaSignupException implements Exception {
  const BetaSignupException(this.message);

  final String message;
}
