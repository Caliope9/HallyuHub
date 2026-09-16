import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';

const storeCategoryChoices = <String>[
  'photocards',
  'albumes',
  'lightsticks',
  'merch',
  'fanmade',
  'otros',
];

const storeDeliveryChoices = <String>[
  'retiro',
  'envio_local',
  'envio_nacional',
  'punto_encuentro',
];

const storePaymentChoices = <String>[
  'transferencia',
  'efectivo',
  'mercado_pago',
  'paypal',
  'otro',
];

String storeOptionLabel(String key) {
  return switch (key) {
    'photocards' => 'Photocards',
    'albumes' => 'Álbumes',
    'lightsticks' => 'Lightsticks',
    'merch' => 'Merch',
    'fanmade' => 'Fanmade',
    'otros' => 'Otros',
    'retiro' => 'Retiro',
    'envio_local' => 'Envío local',
    'envio_nacional' => 'Envío nacional',
    'punto_encuentro' => 'Punto de encuentro',
    'transferencia' => 'Transferencia',
    'efectivo' => 'Efectivo',
    'mercado_pago' => 'Mercado Pago',
    'paypal' => 'PayPal',
    'otro' => 'Otro',
    _ => key,
  };
}

abstract class StoreProfileService {
  const StoreProfileService();

  bool get usesRealStoreProfiles => false;

  Future<StoreProfile?> restoreOwnStore();

  Future<StoreProfile?> restoreStoreForOwner(String ownerId);

  Future<StoreProfile> saveOwnStore(StoreProfileDraft draft);

  Future<StoreProfile> pauseOwnStore();

  Future<StoreProfile> resumeOwnStore();

  Future<StoreProfileAdminData> restoreAdminStores({
    String status = 'all',
    String query = '',
  });

  Future<StoreProfile> updateAdminStore({
    required String id,
    StoreProfileStatus? status,
    bool? isVerified,
  });
}

class LocalStoreProfileService extends StoreProfileService {
  const LocalStoreProfileService();

  static const _storageKey = 'hallyuhub.local.store-profile.v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<StoreProfile?> restoreOwnStore() async {
    final row = await _read();
    return row == null ? null : _storeFromJson(row);
  }

  @override
  Future<StoreProfile?> restoreStoreForOwner(String ownerId) async {
    final store = await restoreOwnStore();
    if (store == null || store.ownerId != ownerId) return null;
    return store.status == StoreProfileStatus.blocked ? null : store;
  }

  @override
  Future<StoreProfile> saveOwnStore(StoreProfileDraft draft) async {
    final storeName = draft.storeName.trim();
    if (storeName.isEmpty) {
      throw const StoreProfileException('Agregá el nombre de tu tienda.');
    }
    final now = DateTime.now().toUtc();
    final previous = await restoreOwnStore();
    final store = StoreProfile(
      id: previous?.id ?? 'local-store-profile',
      ownerId: 'local-user',
      storeName: storeName,
      description: draft.description.trim(),
      country: draft.country.trim(),
      region: draft.region.trim(),
      city: draft.city.trim(),
      categories: _cleanList(draft.categories),
      deliveryMethods: _cleanList(draft.deliveryMethods),
      paymentMethods: _cleanList(draft.paymentMethods),
      contactUrl: draft.contactUrl.trim(),
      instagramUrl: draft.instagramUrl.trim(),
      whatsappUrl: draft.whatsappUrl.trim(),
      openingHours: draft.openingHours.trim(),
      status: previous?.status == StoreProfileStatus.active
          ? StoreProfileStatus.active
          : StoreProfileStatus.pending,
      isVerified: previous?.isVerified ?? false,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _write(_storeToJson(store));
    revision.value++;
    return store;
  }

  @override
  Future<StoreProfile> pauseOwnStore() async {
    final previous = await restoreOwnStore();
    if (previous == null) {
      throw const StoreProfileException('Todavía no tenés perfil tienda.');
    }
    final store = StoreProfile(
      id: previous.id,
      ownerId: previous.ownerId,
      storeName: previous.storeName,
      description: previous.description,
      country: previous.country,
      region: previous.region,
      city: previous.city,
      categories: previous.categories,
      deliveryMethods: previous.deliveryMethods,
      paymentMethods: previous.paymentMethods,
      contactUrl: previous.contactUrl,
      instagramUrl: previous.instagramUrl,
      whatsappUrl: previous.whatsappUrl,
      openingHours: previous.openingHours,
      status: StoreProfileStatus.paused,
      isVerified: previous.isVerified,
      verifiedBy: previous.verifiedBy,
      verifiedAt: previous.verifiedAt,
      profileViews: previous.profileViews,
      contactClicks: previous.contactClicks,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _write(_storeToJson(store));
    revision.value++;
    return store;
  }

  @override
  Future<StoreProfile> resumeOwnStore() async {
    final previous = await restoreOwnStore();
    if (previous == null) {
      throw const StoreProfileException('Todavía no tenés perfil tienda.');
    }
    final store = StoreProfile(
      id: previous.id,
      ownerId: previous.ownerId,
      storeName: previous.storeName,
      description: previous.description,
      country: previous.country,
      region: previous.region,
      city: previous.city,
      categories: previous.categories,
      deliveryMethods: previous.deliveryMethods,
      paymentMethods: previous.paymentMethods,
      contactUrl: previous.contactUrl,
      instagramUrl: previous.instagramUrl,
      whatsappUrl: previous.whatsappUrl,
      openingHours: previous.openingHours,
      status: previous.status == StoreProfileStatus.active
          ? StoreProfileStatus.active
          : StoreProfileStatus.pending,
      isVerified: previous.isVerified,
      verifiedBy: previous.verifiedBy,
      verifiedAt: previous.verifiedAt,
      profileViews: previous.profileViews,
      contactClicks: previous.contactClicks,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _write(_storeToJson(store));
    revision.value++;
    return store;
  }

  @override
  Future<StoreProfileAdminData> restoreAdminStores({
    String status = 'all',
    String query = '',
  }) async {
    final store = await restoreOwnStore();
    if (store == null) return const StoreProfileAdminData(entries: []);
    if (status != 'all' && store.status.key != status) {
      return const StoreProfileAdminData(entries: []);
    }
    final normalized = query.trim().toLowerCase();
    if (normalized.isNotEmpty &&
        !'${store.storeName} ${store.description} ${store.country}'
            .toLowerCase()
            .contains(normalized)) {
      return const StoreProfileAdminData(entries: []);
    }
    return StoreProfileAdminData(entries: [store]);
  }

  @override
  Future<StoreProfile> updateAdminStore({
    required String id,
    StoreProfileStatus? status,
    bool? isVerified,
  }) async {
    final previous = await restoreOwnStore();
    if (previous == null || previous.id != id) {
      throw const StoreProfileException('No encontramos esa tienda.');
    }
    final store = StoreProfile(
      id: previous.id,
      ownerId: previous.ownerId,
      storeName: previous.storeName,
      description: previous.description,
      country: previous.country,
      region: previous.region,
      city: previous.city,
      categories: previous.categories,
      deliveryMethods: previous.deliveryMethods,
      paymentMethods: previous.paymentMethods,
      contactUrl: previous.contactUrl,
      instagramUrl: previous.instagramUrl,
      whatsappUrl: previous.whatsappUrl,
      openingHours: previous.openingHours,
      status: status ?? previous.status,
      isVerified: isVerified ?? previous.isVerified,
      verifiedBy: previous.verifiedBy,
      verifiedAt: (isVerified ?? previous.isVerified)
          ? previous.verifiedAt ?? DateTime.now().toUtc()
          : null,
      profileViews: previous.profileViews,
      contactClicks: previous.contactClicks,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _write(_storeToJson(store));
    revision.value++;
    return store;
  }

  Future<Map<String, dynamic>?> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    if (stored == null) return null;
    try {
      return (jsonDecode(stored) as Map).cast<String, dynamic>();
    } catch (_) {
      await preferences.remove(_storageKey);
      return null;
    }
  }

  Future<void> _write(Map<String, dynamic> row) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(row));
  }
}

class SupabaseStoreProfileService extends StoreProfileService {
  SupabaseStoreProfileService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealStoreProfiles => true;

  static const _select = '''
id,owner_id,store_name,description,country,region,city,categories,
delivery_methods,payment_methods,contact_url,instagram_url,whatsapp_url,
opening_hours,status,is_verified,verified_by,verified_at,profile_views,
contact_clicks,created_at,updated_at,
owner:owner_id(id,name,username,bio,avatar_asset,avatar_url,fandom,
country,city,content_region,location_visibility,favorite_group,private_profile)
''';

  @override
  Future<StoreProfile?> restoreOwnStore() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    try {
      final row = await _client
          .from('store_profiles')
          .select(_select)
          .eq('owner_id', authUser.id)
          .maybeSingle();
      return row == null ? null : _storeFromRow(row);
    } catch (error) {
      debugPrint('STORE_PROFILE_RESTORE_OWN_ERROR error=$error');
      rethrow;
    }
  }

  @override
  Future<StoreProfile?> restoreStoreForOwner(String ownerId) async {
    final safeOwnerId = ownerId.trim();
    if (safeOwnerId.isEmpty) return null;
    try {
      final row = await _client
          .from('store_profiles')
          .select(_select)
          .eq('owner_id', safeOwnerId)
          .maybeSingle();
      return row == null ? null : _storeFromRow(row);
    } catch (error) {
      debugPrint(
        'STORE_PROFILE_RESTORE_OWNER_ERROR ownerId=$safeOwnerId error=$error',
      );
      return null;
    }
  }

  @override
  Future<StoreProfile> saveOwnStore(StoreProfileDraft draft) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const StoreProfileException('Necesitás iniciar sesión.');
    }
    final storeName = draft.storeName.trim();
    if (storeName.isEmpty) {
      throw const StoreProfileException('Agregá el nombre de tu tienda.');
    }
    try {
      final payload = <String, dynamic>{
        'store_name': storeName,
        'description': _nullable(draft.description),
        'country': _nullable(draft.country),
        'region': _nullable(draft.region),
        'city': _nullable(draft.city),
        'categories': _cleanList(draft.categories),
        'delivery_methods': _cleanList(draft.deliveryMethods),
        'payment_methods': _cleanList(draft.paymentMethods),
        'contact_url': _nullable(draft.contactUrl),
        'instagram_url': _nullable(draft.instagramUrl),
        'whatsapp_url': _nullable(draft.whatsappUrl),
        'opening_hours': _nullable(draft.openingHours),
      };
      final updated = await _client
          .from('store_profiles')
          .update(payload)
          .eq('owner_id', authUser.id)
          .select(_select)
          .maybeSingle();
      final row =
          updated ??
          await _client
              .from('store_profiles')
              .insert({...payload, 'owner_id': authUser.id})
              .select(_select)
              .single();
      LocalStoreProfileService.revision.value++;
      return _storeFromRow(row);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'STORE_PROFILE_SAVE_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw StoreProfileException(_messageFor(error));
    } catch (error) {
      debugPrint('STORE_PROFILE_SAVE_ERROR error=$error');
      if (error is StoreProfileException) rethrow;
      throw const StoreProfileException(
        'No pudimos guardar el perfil tienda. Revisá conexión o permisos.',
      );
    }
  }

  @override
  Future<StoreProfile> pauseOwnStore() async {
    try {
      final row = await _client.rpc(
        'set_my_store_profile_paused',
        params: {'p_paused': true},
      );
      LocalStoreProfileService.revision.value++;
      return _storeFromRow((row as Map).cast<String, dynamic>());
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'STORE_PROFILE_PAUSE_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw StoreProfileException(_messageFor(error));
    }
  }

  @override
  Future<StoreProfile> resumeOwnStore() async {
    try {
      final row = await _client.rpc(
        'set_my_store_profile_paused',
        params: {'p_paused': false},
      );
      LocalStoreProfileService.revision.value++;
      return _storeFromRow((row as Map).cast<String, dynamic>());
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'STORE_PROFILE_RESUME_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw StoreProfileException(_messageFor(error));
    }
  }

  @override
  Future<StoreProfileAdminData> restoreAdminStores({
    String status = 'all',
    String query = '',
  }) async {
    try {
      dynamic request = _client.from('store_profiles').select(_select);
      if (status != 'all') request = request.eq('status', status);
      final rows = await request
          .order('created_at', ascending: false)
          .limit(300);
      final normalized = query.trim().toLowerCase();
      final entries = rows
          .cast<Map<String, dynamic>>()
          .map(_storeFromRow)
          .where((store) {
            if (normalized.isEmpty) return true;
            return [
              store.storeName,
              store.description,
              store.country,
              store.city,
              store.owner?.name ?? '',
              store.owner?.username ?? '',
            ].join(' ').toLowerCase().contains(normalized);
          })
          .toList(growable: false);
      return StoreProfileAdminData(entries: entries);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'STORE_PROFILE_ADMIN_FETCH_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw StoreProfileException(_messageFor(error));
    }
  }

  @override
  Future<StoreProfile> updateAdminStore({
    required String id,
    StoreProfileStatus? status,
    bool? isVerified,
  }) async {
    try {
      final row = await _client.rpc(
        'admin_update_store_profile',
        params: {
          'p_store_id': id,
          'p_status': status?.key,
          'p_is_verified': isVerified,
        },
      );
      LocalStoreProfileService.revision.value++;
      return _storeFromRow((row as Map).cast<String, dynamic>());
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'STORE_PROFILE_ADMIN_UPDATE_ERROR code=${error.code} message=${error.message} details=${error.details}',
      );
      throw StoreProfileException(_messageFor(error));
    }
  }

  String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  String _messageFor(supabase.PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('store_profiles') ||
        message.contains('schema') ||
        error.code == '42703' ||
        error.code == '42P01') {
      return 'Falta correr la migración de perfiles tienda en Supabase.';
    }
    if (message.contains('row-level security') ||
        message.contains('permission') ||
        error.code == '42501') {
      return 'No tenés permisos para completar esta acción.';
    }
    return 'No pudimos completar esta acción. Probá de nuevo.';
  }
}

class StoreProfileException implements Exception {
  const StoreProfileException(this.message);

  final String message;

  @override
  String toString() => 'StoreProfileException: $message';
}

List<String> _cleanList(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    result.add(normalized);
  }
  return result;
}

StoreProfile _storeFromJson(Map<String, dynamic> row) {
  return StoreProfile(
    id: row['id'] as String? ?? '',
    ownerId: row['owner_id'] as String? ?? '',
    storeName: row['store_name'] as String? ?? '',
    description: row['description'] as String? ?? '',
    country: row['country'] as String? ?? '',
    region: row['region'] as String? ?? '',
    city: row['city'] as String? ?? '',
    categories: _stringList(row['categories']),
    deliveryMethods: _stringList(row['delivery_methods']),
    paymentMethods: _stringList(row['payment_methods']),
    contactUrl: row['contact_url'] as String? ?? '',
    instagramUrl: row['instagram_url'] as String? ?? '',
    whatsappUrl: row['whatsapp_url'] as String? ?? '',
    openingHours: row['opening_hours'] as String? ?? '',
    status: StoreProfileStatus.fromKey(row['status'] as String? ?? ''),
    isVerified: row['is_verified'] as bool? ?? false,
    verifiedBy: row['verified_by'] as String? ?? '',
    verifiedAt: DateTime.tryParse(row['verified_at'] as String? ?? ''),
    profileViews: _int(row['profile_views']),
    contactClicks: _int(row['contact_clicks']),
    createdAt:
        DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now().toUtc(),
    updatedAt:
        DateTime.tryParse(row['updated_at'] as String? ?? '') ??
        DateTime.now().toUtc(),
  );
}

StoreProfile _storeFromRow(Map<String, dynamic> row) {
  final ownerRow = (row['owner'] as Map?)?.cast<String, dynamic>();
  return StoreProfile(
    id: row['id'] as String? ?? '',
    ownerId: row['owner_id'] as String? ?? '',
    storeName: row['store_name'] as String? ?? '',
    description: row['description'] as String? ?? '',
    country: row['country'] as String? ?? '',
    region: row['region'] as String? ?? '',
    city: row['city'] as String? ?? '',
    categories: _stringList(row['categories']),
    deliveryMethods: _stringList(row['delivery_methods']),
    paymentMethods: _stringList(row['payment_methods']),
    contactUrl: row['contact_url'] as String? ?? '',
    instagramUrl: row['instagram_url'] as String? ?? '',
    whatsappUrl: row['whatsapp_url'] as String? ?? '',
    openingHours: row['opening_hours'] as String? ?? '',
    status: StoreProfileStatus.fromKey(row['status'] as String? ?? ''),
    isVerified: row['is_verified'] as bool? ?? false,
    verifiedBy: row['verified_by'] as String? ?? '',
    verifiedAt: DateTime.tryParse(row['verified_at'] as String? ?? ''),
    profileViews: _int(row['profile_views']),
    contactClicks: _int(row['contact_clicks']),
    createdAt:
        DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now().toUtc(),
    updatedAt:
        DateTime.tryParse(row['updated_at'] as String? ?? '') ??
        DateTime.now().toUtc(),
    owner: ownerRow == null ? null : _ownerFromRow(ownerRow),
  );
}

Map<String, dynamic> _storeToJson(StoreProfile store) {
  return {
    'id': store.id,
    'owner_id': store.ownerId,
    'store_name': store.storeName,
    'description': store.description,
    'country': store.country,
    'region': store.region,
    'city': store.city,
    'categories': store.categories,
    'delivery_methods': store.deliveryMethods,
    'payment_methods': store.paymentMethods,
    'contact_url': store.contactUrl,
    'instagram_url': store.instagramUrl,
    'whatsapp_url': store.whatsappUrl,
    'opening_hours': store.openingHours,
    'status': store.status.key,
    'is_verified': store.isVerified,
    'verified_by': store.verifiedBy,
    'verified_at': store.verifiedAt?.toIso8601String(),
    'profile_views': store.profileViews,
    'contact_clicks': store.contactClicks,
    'created_at': store.createdAt.toIso8601String(),
    'updated_at': store.updatedAt.toIso8601String(),
  };
}

CommunityProfile _ownerFromRow(Map<String, dynamic> row) {
  final city = row['city'] as String? ?? '';
  final country = row['country'] as String? ?? '';
  final avatarUrl = row['avatar_url'] as String? ?? '';
  final avatarAsset = avatarUrl.isNotEmpty
      ? avatarUrl
      : row['avatar_asset'] as String? ?? '';
  return CommunityProfile(
    id: row['id'] as String? ?? '',
    name: row['name'] as String? ?? 'Tienda HallyuHub',
    username: row['username'] as String? ?? '',
    city: city,
    country: country,
    fandom: row['fandom'] as String? ?? '',
    favoriteGroup: row['favorite_group'] as String? ?? '',
    bio: row['bio'] as String? ?? '',
    avatarAsset: avatarAsset,
    followers: '0',
    posts: '0',
    colors: const [],
    privateProfile: row['private_profile'] as bool? ?? false,
  );
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
