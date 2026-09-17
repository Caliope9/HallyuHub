import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import '../data/legal_documents.dart';
import 'media_upload_limits.dart';
import 'age_policy.dart';

@visibleForTesting
String birthDateMetadataValue(DateTime birthDate) =>
    '${birthDate.year.toString().padLeft(4, '0')}-'
    '${birthDate.month.toString().padLeft(2, '0')}-'
    '${birthDate.day.toString().padLeft(2, '0')}';

@visibleForTesting
String? registrationAgeErrorMessageForTesting(String message) =>
    _registrationAgeErrorMessage(message);

String? _registrationAgeErrorMessage(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('birth_date is required') ||
      normalized.contains('birth date is required')) {
    return 'Ingresá tu fecha de nacimiento para crear la cuenta.';
  }
  if (normalized.contains('birth_date is invalid') ||
      normalized.contains('birth date is invalid') ||
      normalized.contains('birth_date cannot be in the future') ||
      normalized.contains('birth date cannot be in the future')) {
    return 'Ingresá una fecha de nacimiento válida.';
  }
  if (normalized.contains('minimum_age_required') ||
      normalized.contains('available from age 16') ||
      normalized.contains('at least 16 years')) {
    return 'Debes tener al menos 16 años para crear una cuenta en HallyuHub.';
  }
  return null;
}

abstract class AuthService {
  Future<AuthUser?> restoreSession();

  Future<AuthUser> signIn({
    required String login,
    required String password,
    required bool rememberDevice,
  });

  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool communityGuidelinesAccepted = false,
    DateTime? birthDate,
  });

  Future<void> saveUser(AuthUser user);

  Future<void> savePrivateProfile(bool privateProfile);

  Future<void> saveLegalAcceptance(AuthUser user);

  Future<BetaAccessState> ensureBetaAccess(AuthUser user);

  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class LocalAuthService implements AuthService {
  const LocalAuthService();

  static const _accountsKey = 'hallyuhub.accounts.v1';
  static const _sessionKey = 'hallyuhub.session.v1';
  static const _avatarAsset = '';

  @override
  Future<AuthUser?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_sessionKey);
    if (stored == null) return null;
    try {
      return _userFromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (_) {
      await preferences.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<AuthUser> signIn({
    required String login,
    required String password,
    required bool rememberDevice,
  }) async {
    final identity = login.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    final account = _readAccounts(preferences).where((entry) {
      final user = _userFromJson(entry['user'] as Map<String, dynamic>);
      return user.email == identity ||
          user.username == _normalizeUsername(identity);
    }).firstOrNull;

    AuthUser user;
    if (account != null) {
      if (account['passwordHash'] != _hashPassword(password)) {
        throw const AuthException('La contraseña no es correcta.');
      }
      user = _userFromJson(account['user'] as Map<String, dynamic>);
    } else {
      throw const AuthException('No encontramos esa cuenta.');
    }

    if (rememberDevice) {
      await _writeSession(preferences, user);
    } else {
      await preferences.remove(_sessionKey);
    }
    return user;
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool communityGuidelinesAccepted = false,
    DateTime? birthDate,
  }) async {
    _validateBirthDate(birthDate);
    final preferences = await SharedPreferences.getInstance();
    final accounts = _readAccounts(preferences);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = _normalizeUsername(username);
    final alreadyExists = accounts.any((entry) {
      final user = _userFromJson(entry['user'] as Map<String, dynamic>);
      return user.email == normalizedEmail ||
          user.username == normalizedUsername;
    });
    if (alreadyExists) {
      throw const AuthException('Ese email o usuario ya está registrado.');
    }

    final acceptedAt =
        termsAccepted && privacyAccepted && communityGuidelinesAccepted
        ? DateTime.now().toUtc()
        : null;
    final user = AuthUser(
      name: _titleCase(name.trim()),
      username: normalizedUsername,
      email: normalizedEmail,
      avatarAsset: _avatarAsset,
      fandom: '',
      country: '',
      language: 'Español',
      favoriteGroup: '',
      bias: '',
      contentRegion: '',
      termsAcceptedAt: acceptedAt,
      privacyAcceptedAt: acceptedAt,
      communityGuidelinesAcceptedAt: acceptedAt,
      legalVersion: acceptedAt == null ? '' : hallyuHubLegalVersion,
      birthDate: birthDate,
      privateProfile: AgePolicy.isTeen(birthDate) ? true : false,
      messagePrivacy: AgePolicy.isTeen(birthDate) ? 'Seguidores' : 'Seguidores',
      storyPrivacy: AgePolicy.isTeen(birthDate) ? 'Seguidores' : 'Seguidores',
    );
    accounts.add({
      'user': _userToJson(user),
      'passwordHash': _hashPassword(password),
    });
    await preferences.setString(_accountsKey, jsonEncode(accounts));
    await _writeSession(preferences, user);
    return user;
  }

  void _validateBirthDate(DateTime? birthDate) {
    if (birthDate == null) {
      throw const AuthException(
        'Ingresá tu fecha de nacimiento para crear la cuenta.',
      );
    }
    switch (AgePolicy.validate(birthDate)) {
      case AgeGateResult.allowed:
        return;
      case AgeGateResult.blocked:
        throw const AuthException(
          'HallyuHub está disponible desde los 16 años.',
        );
      case AgeGateResult.missingBirthDate:
      case AgeGateResult.invalidBirthDate:
        throw const AuthException('Ingresá una fecha de nacimiento válida.');
    }
  }

  @override
  Future<void> saveUser(AuthUser user) async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = _readAccounts(preferences);
    final session = preferences.getString(_sessionKey);
    final previousUser = session == null
        ? null
        : _userFromJson(jsonDecode(session) as Map<String, dynamic>);
    final index = accounts.indexWhere((entry) {
      final stored = _userFromJson(entry['user'] as Map<String, dynamic>);
      return stored.email == user.email ||
          stored.username == user.username ||
          stored.email == previousUser?.email ||
          stored.username == previousUser?.username;
    });
    if (index != -1) {
      accounts[index] = {...accounts[index], 'user': _userToJson(user)};
      await preferences.setString(_accountsKey, jsonEncode(accounts));
    }
    await _writeSession(preferences, user);
  }

  @override
  Future<void> savePrivateProfile(bool privateProfile) async {
    final user = await restoreSession();
    if (user == null) {
      throw const AuthException('Necesitás iniciar sesión para guardar.');
    }
    await saveUser(user.copyWith(privateProfile: privateProfile));
  }

  @override
  Future<void> saveLegalAcceptance(AuthUser user) => saveUser(user);

  @override
  Future<BetaAccessState> ensureBetaAccess(AuthUser user) async {
    return BetaAccessState.approved();
  }

  @override
  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }

  Future<void> _writeSession(
    SharedPreferences preferences,
    AuthUser user,
  ) async {
    await preferences.setString(_sessionKey, jsonEncode(_userToJson(user)));
  }

  List<Map<String, dynamic>> _readAccounts(SharedPreferences preferences) {
    final stored = preferences.getString(_accountsKey);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _normalizeUsername(String username) {
    final cleaned = username
        .replaceFirst('@', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return '@${cleaned.isEmpty ? 'hallyufan' : cleaned}';
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  static const _avatarAsset = '';
  static const _profileSettingsSelect =
      'id,email,name,username,bio,avatar_asset,avatar_url,fandom,country,'
      'region,city,language,phone,bias,favorite_group,phrase,content_region,'
      'location_visibility,location_updated_at,private_profile,'
      'notifications_enabled,message_privacy,story_privacy,app_theme,'
      'profile_background,notify_messages,notify_stars,notify_comments,'
      'notify_followers,notify_drops,two_factor_enabled,login_alerts,'
      'account_verified,blocked_users,terms_accepted_at,privacy_accepted_at,'
      'community_guidelines_accepted_at,beta_notice_accepted_at,legal_version,'
      'role,created_at,updated_at';

  final supabase.SupabaseClient _client;

  @override
  Future<AuthUser?> restoreSession() async {
    final user = _client.auth.currentUser;
    debugPrint(
      'SESSION_RESTORE_START user_id=${user?.id ?? 'none'} '
      'session=${_client.auth.currentSession != null}',
    );
    if (user == null) return null;
    try {
      final profile = await _profileFor(user);
      debugPrint('SESSION_RESTORE_OK user_id=${user.id}');
      return profile;
    } catch (error) {
      debugPrint(
        'SESSION_RESTORE_PROFILE_ERROR user_id=${user.id} error=$error',
      );
      return _userFromAuth(user);
    }
  }

  @override
  Future<AuthUser> signIn({
    required String login,
    required String password,
    required bool rememberDevice,
  }) async {
    final loginKind = login.trim().contains('@') ? 'email' : 'username';
    debugPrint('LOGIN_START identity_type=$loginKind');
    try {
      final email = await _emailForLogin(login);
      debugPrint('LOGIN_EMAIL_RESOLVED identity_type=$loginKind');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('No pudimos iniciar sesión.');
      }
      debugPrint(
        'LOGIN_AUTH_OK user_id=${user.id} session=${response.session != null}',
      );
      try {
        final profile = await _profileFor(user);
        debugPrint('LOGIN_PROFILE_OK user_id=${user.id}');
        return profile;
      } on AuthException {
        rethrow;
      } catch (error) {
        debugPrint('LOGIN_PROFILE_ERROR user_id=${user.id} error=$error');
        throw _profileLoadExceptionFor(error);
      }
    } on supabase.AuthException catch (error) {
      debugPrint(
        'LOGIN_AUTH_ERROR code=${error.code} status=${error.statusCode} '
        'message=${error.message}',
      );
      throw _signInAuthExceptionFor(error);
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('LOGIN_ERROR error=$error');
      if (_isNetworkError(error)) {
        throw const AuthException('No pudimos conectar. Probá de nuevo.');
      }
      throw const AuthException('No pudimos iniciar sesión. Probá de nuevo.');
    }
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool communityGuidelinesAccepted = false,
    DateTime? birthDate,
  }) async {
    _validateBirthDate(birthDate);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = _normalizeUsername(username);
    try {
      _ensureRegisterEmailLooksReal(normalizedEmail);
      await _ensureEmailAvailable(normalizedEmail);
      await _ensureUsernameAvailable(normalizedUsername);
      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'name': _titleCase(name.trim()),
          'username': normalizedUsername,
          if (birthDate != null)
            'birth_date': birthDateMetadataValue(birthDate),
        },
      );
      final authUser = response.user;
      if (authUser == null) {
        throw const AuthException(
          'Revisá tu email para confirmar la cuenta y después iniciá sesión.',
        );
      }
      final acceptedAt =
          termsAccepted && privacyAccepted && communityGuidelinesAccepted
          ? DateTime.now().toUtc()
          : null;
      final user = AuthUser(
        name: _titleCase(name.trim()),
        username: normalizedUsername,
        email: normalizedEmail,
        avatarAsset: _avatarAsset,
        fandom: '',
        country: '',
        language: 'Español',
        favoriteGroup: '',
        bias: '',
        contentRegion: '',
        termsAcceptedAt: acceptedAt,
        privacyAcceptedAt: acceptedAt,
        communityGuidelinesAcceptedAt: acceptedAt,
        legalVersion: acceptedAt == null ? '' : hallyuHubLegalVersion,
        birthDate: birthDate,
        privateProfile: AgePolicy.isTeen(birthDate),
        messagePrivacy: 'Seguidores',
        storyPrivacy: 'Seguidores',
      );
      if (response.session == null) {
        return _completeSignupWithoutSession(
          email: normalizedEmail,
          password: password,
          authUser: authUser,
          fallback: user,
        );
      }
      try {
        await _upsertProfile(authUser.id, user);
      } catch (_) {
        // The database trigger creates the profile. A transient profile upsert
        // should not turn a successful signup into a false failure.
      }
      return _profileForWithRetry(authUser, fallback: user);
    } on AuthException {
      rethrow;
    } catch (error) {
      throw _registerExceptionFor(error);
    }
  }

  Future<AuthUser> _completeSignupWithoutSession({
    required String email,
    required String password,
    required supabase.User authUser,
    required AuthUser fallback,
  }) async {
    try {
      final loginResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final signedInUser = loginResponse.user;
      if (signedInUser == null || loginResponse.session == null) {
        throw const AuthException(
          'Cuenta creada. Revisá tu email para confirmar el acceso.',
        );
      }
      try {
        await _upsertProfile(signedInUser.id, fallback);
      } catch (_) {
        // The trigger may already have created the profile, and older schemas
        // can be completed by the Supabase migration without failing signup.
      }
      return _profileForWithRetry(signedInUser, fallback: fallback);
    } on supabase.AuthException catch (error) {
      final message = error.message.toLowerCase();
      final code = (error.code ?? '').toLowerCase();
      if (message.contains('confirm') ||
          message.contains('verified') ||
          message.contains('not confirmed') ||
          code.contains('email_not_confirmed')) {
        throw const AuthException(
          'Cuenta creada. Revisá tu email para confirmar el acceso.',
        );
      }
      throw const AuthException(
        'Cuenta creada. Iniciá sesión con tu email y contraseña.',
      );
    } catch (error) {
      if (error is AuthException) rethrow;
      try {
        return _profileForWithRetry(authUser, fallback: fallback);
      } catch (_) {
        throw const AuthException(
          'Cuenta creada. Iniciá sesión con tu email y contraseña.',
        );
      }
    }
  }

  @override
  Future<void> saveUser(AuthUser user) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Necesitás iniciar sesión para guardar.');
    }
    try {
      final payload = await _profileSettingsPayload(authUser.id, user);
      assert(() {
        debugPrint(
          'PROFILE_SETTINGS_UPDATE_PAYLOAD user_id=${authUser.id} '
          'keys=${payload.keys.join(',')} '
          'country=${payload['country']} language=${payload['language']} '
          'private_profile=${payload['private_profile']}',
        );
        return true;
      }());
      await _updateProfile(authUser.id, payload);
      final savedProfile = await _profileRow(authUser.id);
      if (savedProfile == null) {
        throw const AuthException(
          'No pudimos volver a leer tu perfil guardado.',
        );
      }
      assert(() {
        debugPrint(
          'PROFILE_SETTINGS_UPDATE_CONFIRMED user_id=${authUser.id} '
          'country=${savedProfile['country']} language=${savedProfile['language']} '
          'private_profile=${savedProfile['private_profile']}',
        );
        return true;
      }());
      _assertProfileSettingsSaved(user, savedProfile);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'PROFILE_SETTINGS_UPDATE_ERROR code=${error.code} '
        'message=${error.message} details=${error.details}',
      );
      throw _profileSettingsExceptionFor(error);
    }
  }

  @override
  Future<void> savePrivateProfile(bool privateProfile) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Necesitás iniciar sesión para guardar.');
    }
    try {
      debugPrint(
        'PROFILE_PRIVACY_SAVE_START user_id=${authUser.id} private_profile=$privateProfile',
      );
      final updated = await _client
          .from('profiles')
          .update({'private_profile': privateProfile})
          .eq('id', authUser.id)
          .select('private_profile')
          .maybeSingle();
      if (updated == null) {
        throw const AuthException(
          'No pudimos encontrar tu perfil para guardar la privacidad.',
        );
      }
      final savedPrivateProfile = _bool(updated, 'private_profile', false);
      debugPrint(
        'PROFILE_PRIVACY_SAVE_CONFIRMED user_id=${authUser.id} private_profile=$savedPrivateProfile',
      );
      if (savedPrivateProfile != privateProfile) {
        throw const AuthException(
          'No pudimos guardar la privacidad del perfil. Probá de nuevo.',
        );
      }
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'PROFILE_PRIVACY_SAVE_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw _profilePrivacyExceptionFor(error);
    }
  }

  @override
  Future<void> saveLegalAcceptance(AuthUser user) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Necesitás iniciar sesión para guardar.');
    }
    try {
      debugPrint('LEGAL_ACCEPTANCE_SAVE_START user_id=${authUser.id}');
      final profile = await _profileRow(authUser.id);
      if (profile == null) {
        debugPrint('LEGAL_ACCEPTANCE_PROFILE_MISSING user_id=${authUser.id}');
        await _ensureMinimalProfile(
          authUser.id,
          authUser.email ?? user.email,
          user,
        );
      }
      await _client
          .from('profiles')
          .update(_legalAcceptancePayload(user))
          .eq('id', authUser.id);
      debugPrint('LEGAL_ACCEPTANCE_SAVE_OK user_id=${authUser.id}');
    } on supabase.PostgrestException catch (error) {
      _logLegalAcceptanceError(error);
      throw _legalAcceptanceExceptionFor(error);
    } catch (error) {
      debugPrint('LEGAL_ACCEPTANCE_SAVE_ERROR error=$error');
      final text = error.toString().toLowerCase();
      if (text.contains('xmlhttprequest') ||
          text.contains('socketexception') ||
          text.contains('clientexception') ||
          text.contains('failed host lookup') ||
          text.contains('failed to fetch')) {
        throw const AuthException('No pudimos conectar. Probá de nuevo.');
      }
      throw const AuthException(
        'No pudimos preparar tu perfil. Cerrá sesión e intentá nuevamente.',
      );
    }
  }

  @override
  Future<BetaAccessState> ensureBetaAccess(AuthUser user) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Necesitás iniciar sesión para entrar.');
    }
    Map<String, dynamic>? accessBeforeRpc;
    try {
      debugPrint(
        'BETA_ACCESS_CHECK_START user_id=${authUser.id} email=${authUser.email ?? user.email}',
      );
      final profileSnapshot = await _readOwnProfileForBeta(authUser.id);
      debugPrint(
        'BETA_ACCESS_PROFILE id=${profileSnapshot?['id'] ?? authUser.id} email=${profileSnapshot?['email'] ?? authUser.email ?? user.email} role=${profileSnapshot?['role'] ?? user.role}',
      );
      final betaRole = (profileSnapshot?['role'] as String? ?? user.role)
          .trim()
          .toLowerCase();
      if (betaRole == 'admin' || betaRole == 'moderator') {
        debugPrint(
          'BETA_ACCESS_ADMIN_BYPASS user_id=${authUser.id} role=$betaRole',
        );
        return BetaAccessState.approved();
      }
      accessBeforeRpc = await _readOwnBetaAccess(authUser.id);
      debugPrint(
        'BETA_ACCESS_BEFORE_RPC user_id=${accessBeforeRpc?['user_id'] ?? authUser.id} email=${accessBeforeRpc?['email'] ?? authUser.email ?? user.email} status=${accessBeforeRpc?['status'] ?? 'missing'}',
      );
      final response = await _claimBetaAccess();
      final row = _betaAccessRow(response);
      final rpcAccess = BetaAccessState.fromJson(row);
      debugPrint('BETA_ACCESS_RPC_RESPONSE row=$row');
      final accessAfterRpc = await _readOwnBetaAccess(authUser.id);
      debugPrint(
        'BETA_ACCESS_AFTER_RPC user_id=${accessAfterRpc?['user_id'] ?? authUser.id} email=${accessAfterRpc?['email'] ?? authUser.email ?? user.email} status=${accessAfterRpc?['status'] ?? 'missing'}',
      );
      final access = _resolveBetaAccess(
        rpcAccess: rpcAccess,
        directAccess: accessAfterRpc ?? accessBeforeRpc,
      );
      debugPrint(
        'BETA_ACCESS_CHECK_OK user_id=${authUser.id} rpc_status=${row['status']} resolved_status=${access.status.name} limit=${access.userLimit} approved=${access.approvedCount}',
      );
      return access;
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'BETA_ACCESS_CHECK_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      final directAccess =
          await _readOwnBetaAccess(authUser.id) ?? accessBeforeRpc;
      final directState = _betaAccessStateFromDirectAccess(directAccess);
      if (directState != null) {
        debugPrint(
          'BETA_ACCESS_FALLBACK_DIRECT user_id=${authUser.id} status=${directState.status.name}',
        );
        return directState;
      }
      throw _betaAccessExceptionFor(error);
    } catch (error) {
      debugPrint('BETA_ACCESS_CHECK_ERROR error=$error');
      final directAccess =
          await _readOwnBetaAccess(authUser.id) ?? accessBeforeRpc;
      final directState = _betaAccessStateFromDirectAccess(directAccess);
      if (directState != null) {
        debugPrint(
          'BETA_ACCESS_FALLBACK_DIRECT user_id=${authUser.id} status=${directState.status.name}',
        );
        return directState;
      }
      final text = error.toString().toLowerCase();
      if (text.contains('xmlhttprequest') ||
          text.contains('socketexception') ||
          text.contains('clientexception') ||
          text.contains('failed host lookup') ||
          text.contains('failed to fetch')) {
        throw const AuthException('No pudimos conectar. Probá de nuevo.');
      }
      throw const AuthException(
        'No pudimos validar tu acceso anticipado. Probá nuevamente.',
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Map<String, dynamic> _betaAccessRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final row = response.first;
      if (row is Map) return row.cast<String, dynamic>();
    }
    if (response is Map) return response.cast<String, dynamic>();
    return const {
      'status': 'waitlist',
      'beta_user_limit': 100,
      'approved_count': 0,
      'position': null,
    };
  }

  Future<Map<String, dynamic>?> _readOwnProfileForBeta(String userId) async {
    try {
      return _profileRow(userId);
    } catch (error) {
      debugPrint('BETA_ACCESS_PROFILE_READ_ERROR error=$error');
      return null;
    }
  }

  Future<dynamic> _claimBetaAccess() async {
    try {
      return await _client.rpc('claim_beta_access_v2');
    } on supabase.PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      final details = error.details.toString().toLowerCase();
      if (error.code == '42883' ||
          message.contains('claim_beta_access_v2') ||
          details.contains('claim_beta_access_v2')) {
        debugPrint('BETA_ACCESS_V2_MISSING fallback=claim_beta_access');
        return _client.rpc('claim_beta_access');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _readOwnBetaAccess(String userId) async {
    try {
      final row = await _client
          .from('beta_access')
          .select('user_id,email,status')
          .eq('user_id', userId)
          .maybeSingle();
      return row?.cast<String, dynamic>();
    } catch (error) {
      debugPrint('BETA_ACCESS_DIRECT_READ_ERROR error=$error');
      return null;
    }
  }

  BetaAccessState _resolveBetaAccess({
    required BetaAccessState rpcAccess,
    required Map<String, dynamic>? directAccess,
  }) {
    final directState = _betaAccessStateFromDirectAccess(
      directAccess,
      base: rpcAccess,
    );
    if (directState != null) return directState;
    return rpcAccess;
  }

  BetaAccessState? _betaAccessStateFromDirectAccess(
    Map<String, dynamic>? directAccess, {
    BetaAccessState? base,
  }) {
    final directStatus = directAccess?['status'];
    if (directStatus is! String) return null;
    final normalizedStatus = directStatus.trim().toLowerCase();
    final userLimit = base?.userLimit ?? 100;
    final approvedCount = base?.approvedCount ?? 0;
    if (normalizedStatus == 'blocked') {
      return BetaAccessState(
        status: BetaAccessStatus.blocked,
        userLimit: userLimit,
        approvedCount: approvedCount,
        position: base?.position,
      );
    }
    if (normalizedStatus == 'approved') {
      return BetaAccessState(
        status: BetaAccessStatus.approved,
        userLimit: userLimit,
        approvedCount: approvedCount,
        position: base?.position,
      );
    }
    if (normalizedStatus == 'waitlist' || normalizedStatus == 'waiting') {
      return BetaAccessState(
        status: BetaAccessStatus.waitlist,
        userLimit: userLimit,
        approvedCount: approvedCount,
        position: base?.position,
      );
    }
    return null;
  }

  Future<String> _emailForLogin(String login) async {
    final identity = login.trim().toLowerCase();
    if (identity.contains('@') && !identity.startsWith('@')) return identity;
    throw const AuthException('Entrá con tu email para iniciar sesión.');
  }

  Future<AuthUser> _profileFor(supabase.User user) async {
    debugPrint('LOGIN_PROFILE_QUERY_START user_id=${user.id}');
    final profile = await _profileRow(user.id);
    if (profile == null) {
      debugPrint('LOGIN_PROFILE_MISSING user_id=${user.id}');
      final fallback = _userFromAuth(user);
      try {
        await _upsertProfile(user.id, fallback);
        debugPrint('LOGIN_PROFILE_CREATED user_id=${user.id}');
      } catch (error) {
        debugPrint(
          'LOGIN_PROFILE_CREATE_ERROR user_id=${user.id} error=$error',
        );
      }
      return fallback;
    }
    debugPrint('LOGIN_PROFILE_QUERY_OK user_id=${user.id}');
    return _userFromProfile(profile, user.email ?? '');
  }

  Future<AuthUser> _profileForWithRetry(
    supabase.User user, {
    required AuthUser fallback,
  }) async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      try {
        final profile = await _profileRow(user.id);
        if (profile != null) return _userFromProfile(profile, user.email ?? '');
      } catch (_) {
        // Keep retrying briefly; the trigger may still be settling.
      }
      await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> _profileRow(String userId) async {
    try {
      final response = await _client.rpc('get_my_profile_settings');
      if (response is Map) {
        final row = response.cast<String, dynamic>();
        if (row['role'] is String) return row;
        debugPrint(
          'PROFILE_SETTINGS_RPC_ROLE_MISSING fallback=profiles_select',
        );
      }
    } on supabase.PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      final details = error.details.toString().toLowerCase();
      if (error.code != '42883' &&
          !message.contains('get_my_profile_settings') &&
          !details.contains('get_my_profile_settings')) {
        rethrow;
      }
      debugPrint('PROFILE_SETTINGS_RPC_MISSING fallback=profiles_select');
    }
    return _client
        .from('profiles')
        .select(_profileSettingsSelect)
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> _ensureUsernameAvailable(String username) async {
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    if (existing != null) {
      throw const AuthException('Ese usuario ya está en uso.');
    }
  }

  Future<void> _ensureEmailAvailable(String email) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (existing != null) {
        throw const AuthException(
          'Ese email ya está registrado. Probá iniciar sesión.',
        );
      }
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('PROFILE_EMAIL_AVAILABILITY_SKIPPED error=$error');
    }
  }

  void _validateBirthDate(DateTime? birthDate) {
    if (birthDate == null) {
      throw const AuthException(
        'Ingresá tu fecha de nacimiento para crear la cuenta.',
      );
    }
    switch (AgePolicy.validate(birthDate)) {
      case AgeGateResult.allowed:
        return;
      case AgeGateResult.blocked:
        throw const AuthException(
          'HallyuHub está disponible desde los 16 años.',
        );
      case AgeGateResult.missingBirthDate:
      case AgeGateResult.invalidBirthDate:
        throw const AuthException('Ingresá una fecha de nacimiento válida.');
    }
  }

  void _ensureRegisterEmailLooksReal(String email) {
    final validShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    final domain = email.contains('@') ? email.split('@').last : '';
    final reservedDomain =
        domain == 'localhost' ||
        domain.endsWith('.localhost') ||
        domain.endsWith('.test') ||
        domain.endsWith('.example') ||
        domain.endsWith('.invalid');
    if (!validShape || reservedDomain) {
      throw const AuthException('Usa un email real para crear la cuenta.');
    }
  }

  Future<void> _upsertProfile(String id, AuthUser user) async {
    await _client
        .from('profiles')
        .upsert(
          await _profilePayload(id, user, includeId: true),
          onConflict: 'id',
        );
  }

  Future<void> _updateProfile(String id, Map<String, dynamic> payload) async {
    final updated = await _client
        .from('profiles')
        .update(payload)
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw const AuthException(
        'No pudimos encontrar tu perfil para guardar los cambios.',
      );
    }
  }

  Future<void> _ensureMinimalProfile(
    String id,
    String email,
    AuthUser user,
  ) async {
    await _client.from('profiles').upsert({
      'id': id,
      'email': email,
      'name': user.name,
      'username': user.username,
    }, onConflict: 'id');
  }

  Map<String, dynamic> _legalAcceptancePayload(AuthUser user) {
    return {
      'terms_accepted_at': user.termsAcceptedAt?.toIso8601String(),
      'privacy_accepted_at': user.privacyAcceptedAt?.toIso8601String(),
      'community_guidelines_accepted_at': user.communityGuidelinesAcceptedAt
          ?.toIso8601String(),
      'beta_notice_accepted_at': user.betaNoticeAcceptedAt?.toIso8601String(),
      'legal_version': user.legalVersion,
    };
  }

  Future<Map<String, dynamic>> _profilePayload(
    String id,
    AuthUser user, {
    bool includeId = false,
  }) async {
    final avatar = await _resolveAvatar(id, user.avatarAsset);
    return {
      if (includeId) 'id': id,
      'email': user.email,
      'name': user.name,
      'username': user.username,
      'bio': user.bio,
      'avatar_asset': avatar.asset,
      'avatar_url': avatar.publicUrl,
      'fandom': user.fandom,
      'country': user.country,
      'region': user.region,
      'city': user.city,
      'language': user.language,
      'phone': user.phone,
      'bias': user.bias,
      'favorite_group': user.favoriteGroup,
      'phrase': user.phrase,
      'content_region': user.contentRegion,
      'location_visibility': user.locationVisibility,
      'location_updated_at': user.locationUpdatedAt?.toIso8601String(),
      'private_profile': user.privateProfile,
      'notifications_enabled': user.notificationsEnabled,
      'message_privacy': user.messagePrivacy,
      'story_privacy': user.storyPrivacy,
      'app_theme': user.appTheme,
      'profile_background': user.profileBackground,
      'notify_messages': user.notifyMessages,
      'notify_stars': user.notifyStars,
      'notify_comments': user.notifyComments,
      'notify_followers': user.notifyFollowers,
      'notify_drops': user.notifyDrops,
      'two_factor_enabled': user.twoFactorEnabled,
      'login_alerts': user.loginAlerts,
      'account_verified': user.accountVerified,
      'blocked_users': user.blockedUsers,
      'terms_accepted_at': user.termsAcceptedAt?.toIso8601String(),
      'privacy_accepted_at': user.privacyAcceptedAt?.toIso8601String(),
      'community_guidelines_accepted_at': user.communityGuidelinesAcceptedAt
          ?.toIso8601String(),
      'beta_notice_accepted_at': user.betaNoticeAcceptedAt?.toIso8601String(),
      'legal_version': user.legalVersion,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _profileSettingsPayload(
    String id,
    AuthUser user,
  ) async {
    final avatar = await _resolveAvatar(id, user.avatarAsset);
    return {
      'name': _requiredProfileText(user.name, 'Hallyu Fan'),
      'username': _normalizeUsername(user.username),
      'bio': _nullableText(user.bio),
      'avatar_asset': _nullableText(avatar.asset),
      'avatar_url': _nullableText(avatar.publicUrl ?? ''),
      'fandom': _nullableText(user.fandom),
      'country': _nullableText(user.country),
      'region': _nullableText(user.region),
      'city': _nullableText(user.city),
      'language': _requiredProfileText(user.language, 'Español'),
      'bias': _nullableText(user.bias),
      'favorite_group': _nullableText(user.favoriteGroup),
      'phrase': _nullableText(user.phrase),
      'content_region': _nullableText(user.contentRegion),
      'location_visibility': _requiredProfileText(
        user.locationVisibility,
        'country',
      ),
      'location_updated_at': user.locationUpdatedAt?.toIso8601String(),
      'private_profile': user.privateProfile,
      'notifications_enabled': user.notificationsEnabled,
      'message_privacy': _requiredProfileText(
        user.messagePrivacy,
        'Seguidores',
      ),
      'story_privacy': _requiredProfileText(user.storyPrivacy, 'Seguidores'),
      'app_theme': _requiredProfileText(user.appTheme, 'Sistema'),
      'profile_background': _requiredProfileText(
        user.profileBackground,
        'Pastel neon',
      ),
      'notify_messages': user.notifyMessages,
      'notify_stars': user.notifyStars,
      'notify_comments': user.notifyComments,
      'notify_followers': user.notifyFollowers,
      'notify_drops': user.notifyDrops,
    };
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _requiredProfileText(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  void _assertProfileSettingsSaved(
    AuthUser requested,
    Map<String, dynamic> savedProfile,
  ) {
    final checks = <String, (String, String)>{
      'name': (requested.name, _string(savedProfile, 'name', '')),
      'username': (
        _normalizeUsername(requested.username),
        _normalizeUsername(_string(savedProfile, 'username', '')),
      ),
      'country': (requested.country, _string(savedProfile, 'country', '')),
      'region': (requested.region, _string(savedProfile, 'region', '')),
      'city': (requested.city, _string(savedProfile, 'city', '')),
      'language': (requested.language, _string(savedProfile, 'language', '')),
      'fandom': (requested.fandom, _string(savedProfile, 'fandom', '')),
      'favorite_group': (
        requested.favoriteGroup,
        _string(savedProfile, 'favorite_group', ''),
      ),
      'bias': (requested.bias, _string(savedProfile, 'bias', '')),
      'content_region': (
        requested.contentRegion,
        _string(savedProfile, 'content_region', ''),
      ),
    };
    for (final entry in checks.entries) {
      final requestedValue = entry.value.$1.trim();
      final savedValue = entry.value.$2.trim();
      if (requestedValue != savedValue) {
        debugPrint(
          'PROFILE_SETTINGS_VERIFY_MISMATCH field=${entry.key} '
          'requested=$requestedValue saved=$savedValue',
        );
        throw const AuthException(
          'No pudimos confirmar que el perfil quedó guardado.',
        );
      }
    }
    final savedPrivateProfile = _bool(savedProfile, 'private_profile', false);
    if (savedPrivateProfile != requested.privateProfile) {
      throw const AuthException(
        'No pudimos guardar la privacidad del perfil. Probá de nuevo.',
      );
    }
  }

  AuthException _signInAuthExceptionFor(supabase.AuthException error) {
    final message = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    final statusCode = error.statusCode;
    if (statusCode == '400' ||
        code.contains('invalid_credentials') ||
        code.contains('invalid_login_credentials') ||
        message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return const AuthException('Email o contraseña incorrectos.');
    }
    if (code.contains('email_not_confirmed') ||
        message.contains('email not confirmed') ||
        message.contains('not confirmed')) {
      return const AuthException(
        'Revisá tu email para confirmar la cuenta antes de entrar.',
      );
    }
    if (statusCode == '429' ||
        code.contains('rate') ||
        message.contains('rate limit') ||
        message.contains('too many')) {
      return const AuthException(
        'Demasiados intentos. Esperá unos minutos y probá de nuevo.',
      );
    }
    if (error is supabase.AuthRetryableFetchException ||
        message.contains('network') ||
        message.contains('failed to fetch') ||
        message.contains('connection')) {
      return const AuthException('No pudimos conectar. Probá de nuevo.');
    }
    return const AuthException('No pudimos iniciar sesión. Probá de nuevo.');
  }

  AuthException _profileLoadExceptionFor(Object error) {
    if (error is supabase.PostgrestException) {
      final message = error.message.toLowerCase();
      final details = error.details.toString().toLowerCase();
      final code = (error.code ?? '').toLowerCase();
      if (code == '42501' ||
          message.contains('permission') ||
          message.contains('policy') ||
          message.contains('row-level security') ||
          message.contains('rls')) {
        return const AuthException(
          'Pudimos iniciar sesión, pero no cargar tu perfil por permisos de Supabase.',
        );
      }
      if (code == 'pgrst204' ||
          message.contains('column') ||
          message.contains('schema cache') ||
          details.contains('profiles')) {
        return const AuthException(
          'Pudimos iniciar sesión, pero falta actualizar el perfil en Supabase.',
        );
      }
    }
    if (_isNetworkError(error)) {
      return const AuthException(
        'Pudimos iniciar sesión, pero no cargar tu perfil por conexión.',
      );
    }
    return const AuthException(
      'Pudimos iniciar sesión, pero no cargar tu perfil. Probá de nuevo.',
    );
  }

  bool _isNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return error is supabase.AuthRetryableFetchException ||
        text.contains('xmlhttprequest') ||
        text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('failed to fetch') ||
        text.contains('network') ||
        text.contains('connection');
  }

  AuthException _registerExceptionFor(Object error) {
    final ageErrorMessage = _registrationAgeErrorMessage(error.toString());
    if (ageErrorMessage != null) return AuthException(ageErrorMessage);

    if (error is supabase.AuthException) {
      final message = error.message.toLowerCase();
      final code = (error.code ?? '').toLowerCase();
      final statusCode = error.statusCode;
      if (code.contains('invalid') && code.contains('email') ||
          message.contains('email address') && message.contains('invalid') ||
          message.contains('invalid email')) {
        return const AuthException('Usa un email real para crear la cuenta.');
      }
      if (statusCode == '429' ||
          code.contains('rate') ||
          message.contains('rate limit') ||
          message.contains('too many')) {
        return const AuthException(
          'Demasiados intentos. Esperá unos minutos y probá de nuevo.',
        );
      }
      if (code.contains('already') ||
          code.contains('user_exists') ||
          code.contains('email_exists') ||
          message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('user already registered')) {
        return const AuthException(
          'Ese email ya está registrado. Probá iniciar sesión.',
        );
      }
      if (error is supabase.AuthRetryableFetchException ||
          message.contains('network') ||
          message.contains('failed to fetch') ||
          message.contains('connection')) {
        return const AuthException('No pudimos conectar con el servidor.');
      }
      if (code.contains('weak_password') || message.contains('password')) {
        return AuthException(error.message);
      }
    }

    if (error is supabase.PostgrestException) {
      final message = error.message.toLowerCase();
      final details = error.details.toString().toLowerCase();
      if (error.code == '23505') {
        if (details.contains('username') || message.contains('username')) {
          return const AuthException('Ese usuario ya está en uso.');
        }
        if (details.contains('email') || message.contains('email')) {
          return const AuthException(
            'Ese email ya está registrado. Probá iniciar sesión.',
          );
        }
      }
      if (message.contains('failed to fetch') ||
          message.contains('connection')) {
        return const AuthException('No pudimos conectar con el servidor.');
      }
    }

    final text = error.toString().toLowerCase();
    if (text.contains('xmlhttprequest') ||
        text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('failed to fetch')) {
      return const AuthException('No pudimos conectar con el servidor.');
    }
    if (text.contains('rate limit') || text.contains('too many')) {
      return const AuthException(
        'Demasiados intentos. Esperá unos minutos y probá de nuevo.',
      );
    }
    if (text.contains('email address') && text.contains('invalid') ||
        text.contains('invalid email')) {
      return const AuthException('Usa un email real para crear la cuenta.');
    }
    if (text.contains('username')) {
      return const AuthException('Ese usuario ya está en uso.');
    }
    if (text.contains('already registered') ||
        text.contains('already exists')) {
      return const AuthException(
        'Ese email ya está registrado. Probá iniciar sesión.',
      );
    }

    return const AuthException('No pudimos crear la cuenta.');
  }

  void _logLegalAcceptanceError(supabase.PostgrestException error) {
    debugPrint(
      'LEGAL_ACCEPTANCE_SAVE_ERROR '
      'code=${error.code} message=${error.message} details=${error.details}',
    );
  }

  AuthException _legalAcceptanceExceptionFor(
    supabase.PostgrestException error,
  ) {
    final message = error.message.toLowerCase();
    final details = error.details.toString().toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    if (code == 'pgrst204' ||
        message.contains('column') ||
        message.contains('schema cache') ||
        details.contains('terms_accepted_at') ||
        details.contains('legal_version')) {
      return const AuthException(
        'Falta actualizar Supabase para guardar la aceptación.',
      );
    }
    if (code == '42501' ||
        message.contains('permission') ||
        message.contains('policy') ||
        message.contains('row-level security') ||
        message.contains('rls')) {
      return const AuthException(
        'No pudimos guardar por permisos del perfil. Avisame para aplicar la policy.',
      );
    }
    if (message.contains('failed to fetch') || message.contains('connection')) {
      return const AuthException('No pudimos conectar. Probá de nuevo.');
    }
    return const AuthException(
      'No pudimos preparar tu perfil. Cerrá sesión e intentá nuevamente.',
    );
  }

  AuthException _profilePrivacyExceptionFor(supabase.PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    if (code == 'pgrst204' ||
        message.contains('private_profile') ||
        message.contains('schema cache') ||
        message.contains('column')) {
      return const AuthException(
        'Falta actualizar Supabase para guardar la privacidad del perfil.',
      );
    }
    if (code == '42501' ||
        message.contains('permission') ||
        message.contains('policy') ||
        message.contains('row-level security') ||
        message.contains('rls')) {
      return const AuthException(
        'No pudimos guardar por permisos del perfil. Hay que aplicar la policy de privacidad.',
      );
    }
    if (message.contains('failed to fetch') || message.contains('connection')) {
      return const AuthException('No pudimos conectar. Probá de nuevo.');
    }
    return const AuthException(
      'No pudimos guardar la privacidad del perfil. Probá de nuevo.',
    );
  }

  AuthException _profileSettingsExceptionFor(
    supabase.PostgrestException error,
  ) {
    final message = error.message.toLowerCase();
    final details = error.details.toString().toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    if (code == 'pgrst204' ||
        message.contains('column') ||
        message.contains('schema cache') ||
        details.contains('profiles')) {
      return const AuthException(
        'Falta actualizar Supabase para guardar todos los datos del perfil.',
      );
    }
    if (code == '42501' ||
        message.contains('permission') ||
        message.contains('policy') ||
        message.contains('row-level security') ||
        message.contains('rls')) {
      return const AuthException(
        'No pudimos guardar por permisos del perfil. Hay que revisar la policy de profiles.',
      );
    }
    if (message.contains('failed to fetch') || message.contains('connection')) {
      return const AuthException('No pudimos conectar. Probá de nuevo.');
    }
    if (code == '23505' ||
        message.contains('duplicate') ||
        message.contains('already exists')) {
      if (message.contains('username') || details.contains('username')) {
        return const AuthException('Ese usuario ya está en uso.');
      }
      if (message.contains('email') || details.contains('email')) {
        return const AuthException('Ese email ya está registrado.');
      }
    }
    return const AuthException(
      'No pudimos guardar los cambios del perfil. Probá de nuevo.',
    );
  }

  AuthException _betaAccessExceptionFor(supabase.PostgrestException error) {
    final message = error.message.toLowerCase();
    final details = error.details.toString().toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    if (code == '42883' ||
        code == 'pgrst202' ||
        message.contains('claim_beta_access') ||
        message.contains('function') ||
        details.contains('claim_beta_access')) {
      return const AuthException(
        'Falta completar la configuración del acceso anticipado en Supabase.',
      );
    }
    if (code == '42p01' ||
        message.contains('beta_access') ||
        message.contains('beta_settings') ||
        message.contains('relation')) {
      return const AuthException(
        'Falta actualizar Supabase para controlar el acceso anticipado.',
      );
    }
    if (code == '42501' ||
        message.contains('permission') ||
        message.contains('policy') ||
        message.contains('row-level security') ||
        message.contains('rls')) {
      return const AuthException(
        'No pudimos validar tu cupo por permisos de Supabase.',
      );
    }
    if (message.contains('failed to fetch') || message.contains('connection')) {
      return const AuthException('No pudimos conectar. Probá de nuevo.');
    }
    return const AuthException(
      'No pudimos validar tu acceso anticipado. Probá nuevamente.',
    );
  }

  Future<_ResolvedAvatar> _resolveAvatar(String userId, String avatar) async {
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return _ResolvedAvatar(asset: avatar, publicUrl: avatar);
    }
    final bytes = _imageBytesFromDataUri(avatar);
    if (bytes == null) {
      return _ResolvedAvatar(asset: avatar, publicUrl: null);
    }
    if (bytes.isEmpty) {
      throw const AuthException('No pudimos leer la foto de perfil.');
    }
    if (bytes.lengthInBytes > MediaUploadLimits.avatarBytes) {
      throw const AuthException('La foto de perfil supera el límite de 5 MB.');
    }
    final detectedContentType = MediaUploadLimits.detectImageContentType(bytes);
    if (detectedContentType == null) {
      throw const AuthException('La foto de perfil debe ser JPG, PNG o WEBP.');
    }

    final contentType = detectedContentType;
    final extension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp',
      _ => 'png',
    };
    final path =
        '$userId/avatar-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    return _ResolvedAvatar(asset: publicUrl, publicUrl: publicUrl);
  }

  AuthUser _userFromAuth(supabase.User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return AuthUser(
      name: _string(metadata, 'name', 'Hallyu Fan'),
      username: _normalizeUsername(
        _string(metadata, 'username', user.email ?? 'fan'),
      ),
      email: user.email ?? '',
      avatarAsset: _avatarAsset,
      fandom: _string(metadata, 'fandom', ''),
      country: '',
      language: 'Español',
      favoriteGroup: _string(metadata, 'favorite_group', ''),
      bias: _string(metadata, 'bias', ''),
      contentRegion: _string(metadata, 'content_region', ''),
    );
  }

  AuthUser _userFromProfile(Map<String, dynamic> json, String authEmail) {
    final avatarUrl = _string(json, 'avatar_url', '');
    final avatarAsset = _string(json, 'avatar_asset', _avatarAsset);
    return AuthUser(
      name: _string(json, 'name', 'Hallyu Fan'),
      username: _normalizeUsername(_string(json, 'username', 'hallyufan')),
      email: _string(json, 'email', authEmail),
      avatarAsset: avatarUrl.isNotEmpty ? avatarUrl : avatarAsset,
      fandom: _string(json, 'fandom', ''),
      bio: _string(
        json,
        'bio',
        'Conecto con fandoms, eventos y colecciones favoritas desde HallyuHub.',
      ),
      country: _string(json, 'country', ''),
      region: _string(json, 'region', ''),
      city: _string(json, 'city', ''),
      language: _string(json, 'language', 'Español'),
      phone: _string(json, 'phone', ''),
      bias: _string(json, 'bias', ''),
      favoriteGroup: _string(json, 'favorite_group', ''),
      phrase: _string(json, 'phrase', 'Compartiendo mi mundo fandom.'),
      contentRegion: _string(json, 'content_region', ''),
      locationVisibility: _string(json, 'location_visibility', 'country'),
      locationUpdatedAt: _date(json, 'location_updated_at'),
      privateProfile: _bool(json, 'private_profile', false),
      notificationsEnabled: _bool(json, 'notifications_enabled', true),
      messagePrivacy: _string(json, 'message_privacy', 'Seguidores'),
      storyPrivacy: _string(json, 'story_privacy', 'Seguidores'),
      appTheme: _string(json, 'app_theme', 'Sistema'),
      profileBackground: _string(json, 'profile_background', 'Pastel neon'),
      notifyMessages: _bool(json, 'notify_messages', true),
      notifyStars: _bool(json, 'notify_stars', true),
      notifyComments: _bool(json, 'notify_comments', true),
      notifyFollowers: _bool(json, 'notify_followers', true),
      notifyDrops: _bool(json, 'notify_drops', true),
      twoFactorEnabled: _bool(json, 'two_factor_enabled', false),
      loginAlerts: _bool(json, 'login_alerts', true),
      accountVerified: _bool(json, 'account_verified', false),
      blockedUsers: _stringList(json, 'blocked_users'),
      termsAcceptedAt: _date(json, 'terms_accepted_at'),
      privacyAcceptedAt: _date(json, 'privacy_accepted_at'),
      communityGuidelinesAcceptedAt: _date(
        json,
        'community_guidelines_accepted_at',
      ),
      betaNoticeAcceptedAt: _date(json, 'beta_notice_accepted_at'),
      legalVersion: _string(json, 'legal_version', ''),
      role: _normalizeRole(_string(json, 'role', 'user')),
      birthDate: _date(json, 'birth_date'),
      enforcementStatus: _string(json, 'enforcement_status', 'active'),
      enforcementUntil: _date(json, 'enforcement_until'),
    );
  }

  String _normalizeRole(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'admin' || 'moderator' => normalized,
      _ => 'user',
    };
  }

  String _normalizeUsername(String username) {
    final cleaned = username
        .replaceFirst('@', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return '@${cleaned.isEmpty ? 'hallyufan' : cleaned}';
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _string(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  bool _bool(Map<String, dynamic> json, String key, bool fallback) {
    final value = json[key];
    if (value is bool) return value;
    return fallback;
  }

  DateTime? _date(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  List<String> _stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is List) return value.whereType<String>().toList();
    return const [];
  }

  Uint8List? _imageBytesFromDataUri(String value) {
    if (!value.startsWith('data:image/')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}

class _ResolvedAvatar {
  const _ResolvedAvatar({required this.asset, required this.publicUrl});

  final String asset;
  final String? publicUrl;
}

Map<String, dynamic> _userToJson(AuthUser user) {
  return {
    'name': user.name,
    'username': user.username,
    'email': user.email,
    'avatarAsset': user.avatarAsset,
    'fandom': user.fandom,
    'bio': user.bio,
    'country': user.country,
    'region': user.region,
    'city': user.city,
    'language': user.language,
    'phone': user.phone,
    'bias': user.bias,
    'favoriteGroup': user.favoriteGroup,
    'phrase': user.phrase,
    'contentRegion': user.contentRegion,
    'locationVisibility': user.locationVisibility,
    'locationUpdatedAt': user.locationUpdatedAt?.toIso8601String(),
    'privateProfile': user.privateProfile,
    'notificationsEnabled': user.notificationsEnabled,
    'messagePrivacy': user.messagePrivacy,
    'storyPrivacy': user.storyPrivacy,
    'appTheme': user.appTheme,
    'profileBackground': user.profileBackground,
    'notifyMessages': user.notifyMessages,
    'notifyStars': user.notifyStars,
    'notifyComments': user.notifyComments,
    'notifyFollowers': user.notifyFollowers,
    'notifyDrops': user.notifyDrops,
    'twoFactorEnabled': user.twoFactorEnabled,
    'loginAlerts': user.loginAlerts,
    'accountVerified': user.accountVerified,
    'blockedUsers': user.blockedUsers,
    'termsAcceptedAt': user.termsAcceptedAt?.toIso8601String(),
    'privacyAcceptedAt': user.privacyAcceptedAt?.toIso8601String(),
    'communityGuidelinesAcceptedAt': user.communityGuidelinesAcceptedAt
        ?.toIso8601String(),
    'betaNoticeAcceptedAt': user.betaNoticeAcceptedAt?.toIso8601String(),
    'legalVersion': user.legalVersion,
    'role': user.role,
    'birthDate': user.birthDate?.toIso8601String(),
    'enforcementStatus': user.enforcementStatus,
    'enforcementUntil': user.enforcementUntil?.toIso8601String(),
  };
}

AuthUser _userFromJson(Map<String, dynamic> json) {
  return AuthUser(
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    avatarAsset: json['avatarAsset'] as String,
    fandom: json['fandom'] as String? ?? '',
    bio: json['bio'] as String,
    country: json['country'] as String? ?? '',
    region: json['region'] as String? ?? '',
    city: json['city'] as String? ?? '',
    language: json['language'] as String,
    phone: json['phone'] as String,
    bias: json['bias'] as String? ?? '',
    favoriteGroup: json['favoriteGroup'] as String? ?? '',
    phrase: json['phrase'] as String? ?? '',
    contentRegion: json['contentRegion'] as String? ?? '',
    locationVisibility: json['locationVisibility'] as String? ?? 'country',
    locationUpdatedAt: DateTime.tryParse(
      json['locationUpdatedAt'] as String? ?? '',
    ),
    privateProfile: json['privateProfile'] as bool,
    notificationsEnabled: json['notificationsEnabled'] as bool,
    messagePrivacy: json['messagePrivacy'] as String,
    storyPrivacy: json['storyPrivacy'] as String,
    appTheme: json['appTheme'] as String,
    profileBackground: json['profileBackground'] as String,
    notifyMessages: json['notifyMessages'] as bool,
    notifyStars: json['notifyStars'] as bool,
    notifyComments: json['notifyComments'] as bool,
    notifyFollowers: json['notifyFollowers'] as bool,
    notifyDrops: json['notifyDrops'] as bool,
    twoFactorEnabled: json['twoFactorEnabled'] as bool,
    loginAlerts: json['loginAlerts'] as bool,
    accountVerified: json['accountVerified'] as bool,
    blockedUsers: (json['blockedUsers'] as List<dynamic>).cast<String>(),
    termsAcceptedAt: DateTime.tryParse(
      json['termsAcceptedAt'] as String? ?? '',
    ),
    privacyAcceptedAt: DateTime.tryParse(
      json['privacyAcceptedAt'] as String? ?? '',
    ),
    communityGuidelinesAcceptedAt: DateTime.tryParse(
      json['communityGuidelinesAcceptedAt'] as String? ?? '',
    ),
    betaNoticeAcceptedAt: DateTime.tryParse(
      json['betaNoticeAcceptedAt'] as String? ?? '',
    ),
    legalVersion: json['legalVersion'] as String? ?? '',
    role: json['role'] as String? ?? 'user',
    birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
    enforcementStatus: json['enforcementStatus'] as String? ?? 'active',
    enforcementUntil: DateTime.tryParse(
      json['enforcementUntil'] as String? ?? '',
    ),
  );
}
