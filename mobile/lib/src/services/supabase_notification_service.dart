import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_notification_service.dart';

class SupabaseNotificationService extends LocalNotificationService {
  SupabaseNotificationService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealNotifications => true;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static Future<void> createFromClient({
    required supabase.SupabaseClient client,
    required String recipientId,
    required String actorId,
    required String type,
    required String entityType,
    required String entityId,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
    bool dedupe = true,
  }) async {
    if (recipientId.trim().isEmpty || actorId.trim().isEmpty) return;
    if (recipientId == actorId) return;
    debugPrint(
      'NOTIFICATION_CREATE_TRIGGER_EXPECTED type=$type entityType=$entityType '
      'entityId=$entityId recipientId=$recipientId actorId=$actorId',
    );
    try {
      debugPrint(
        'NOTIFICATION_CREATE_RPC_START type=$type entityType=$entityType '
        'entityId=$entityId',
      );
      await client.rpc(
        'hallyu_create_notification',
        params: {
          'p_recipient_id': recipientId,
          'p_actor_id': actorId,
          'p_type': type,
          'p_entity_type': entityType,
          'p_entity_id': entityId.trim().isEmpty ? null : entityId,
          'p_title': title,
          'p_body': body,
          'p_metadata': metadata,
          'p_dedupe': dedupe,
        },
      );
      debugPrint(
        'NOTIFICATION_CREATE_RPC_OK type=$type entityType=$entityType '
        'entityId=$entityId',
      );
      LocalNotificationService.revision.value++;
    } catch (error) {
      debugPrint(
        'NOTIFICATION_CREATE_RPC_ERROR type=$type entityType=$entityType '
        'entityId=$entityId error=$error',
      );
      await _createByDirectInsert(
        client: client,
        recipientId: recipientId,
        actorId: actorId,
        type: type,
        entityType: entityType,
        entityId: entityId,
        title: title,
        body: body,
        metadata: metadata,
      );
    }
  }

  static Future<void> _createByDirectInsert({
    required supabase.SupabaseClient client,
    required String recipientId,
    required String actorId,
    required String type,
    required String entityType,
    required String entityId,
    required String title,
    required String body,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      debugPrint(
        'NOTIFICATION_CREATE_DIRECT_INSERT_START type=$type '
        'entityType=$entityType entityId=$entityId',
      );
      await client.from('notifications').insert({
        'recipient_id': recipientId,
        'actor_id': actorId,
        'type': type,
        'entity_type': entityType,
        'entity_id': entityId.trim().isEmpty ? null : entityId,
        'title': title.trim().isEmpty ? 'Notificación' : title,
        'body': body,
        'metadata': metadata,
      });
      debugPrint(
        'NOTIFICATION_CREATE_DIRECT_INSERT_OK type=$type '
        'entityType=$entityType entityId=$entityId',
      );
      LocalNotificationService.revision.value++;
    } catch (insertError) {
      debugPrint(
        'NOTIFICATION_CREATE_DIRECT_INSERT_ERROR type=$type '
        'entityType=$entityType entityId=$entityId error=$insertError',
      );
    }
  }

  @override
  Future<List<HallyuNotification>> restoreNotifications({
    int limit = 80,
  }) async {
    final currentUserId = _currentUserId;
    debugPrint('CURRENT_USER_ID_FOR_NOTIFICATIONS userId=$currentUserId');
    if (currentUserId == null) return const [];
    debugPrint('NOTIFICATIONS_FETCH_START userId=$currentUserId limit=$limit');
    try {
      final rows = await _client
          .from('notifications')
          .select(
            'id,recipient_id,actor_id,type,entity_type,entity_id,title,body,is_read,created_at,metadata',
          )
          .eq('recipient_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(limit);
      final notificationRows = rows.cast<Map<String, dynamic>>();
      final actorIds = notificationRows
          .map((row) => row['actor_id'] as String?)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList(growable: false);
      final actorsById = await _profilesById(actorIds);
      final notifications = rows
          .cast<Map<String, dynamic>>()
          .map((row) => _notificationFromRow(row, actorsById[row['actor_id']]))
          .toList(growable: false);
      debugPrint(
        'NOTIFICATIONS_FETCH_COUNT userId=$currentUserId count=${notifications.length}',
      );
      return notifications;
    } catch (error) {
      debugPrint(
        'NOTIFICATIONS_FETCH_ERROR userId=$currentUserId error=$error',
      );
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _profilesById(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id,name,username,bio,avatar_asset,avatar_url,fandom')
          .inFilter('id', ids);
      return {
        for (final row in rows.cast<Map<String, dynamic>>())
          if ((row['id'] as String? ?? '').isNotEmpty) row['id'] as String: row,
      };
    } catch (error) {
      debugPrint('NOTIFICATIONS_ACTOR_FETCH_ERROR error=$error');
      return const {};
    }
  }

  @override
  Future<int> unreadCount() async {
    final notifications = await restoreNotifications(limit: 120);
    return notifications.where((notification) => !notification.isRead).length;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || notificationId.isEmpty) return;
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId)
        .eq('recipient_id', currentUserId);
    LocalNotificationService.revision.value++;
  }

  @override
  Future<void> markAllRead() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_id', currentUserId)
        .eq('is_read', false);
    LocalNotificationService.revision.value++;
  }

  HallyuNotification _notificationFromRow(
    Map<String, dynamic> row,
    Map<String, dynamic>? actorRow,
  ) {
    final metadata = row['metadata'];
    return HallyuNotification(
      id: row['id'] as String? ?? '',
      recipientId: row['recipient_id'] as String? ?? '',
      actorId: row['actor_id'] as String? ?? '',
      actor: actorRow != null ? _profileFromRow(actorRow) : null,
      type: row['type'] as String? ?? '',
      entityType: row['entity_type'] as String? ?? '',
      entityId: row['entity_id'] as String? ?? '',
      title: row['title'] as String? ?? 'Notificación',
      body: row['body'] as String? ?? '',
      isRead: row['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      metadata: metadata is Map<String, dynamic> ? metadata : const {},
    );
  }

  CommunityProfile _profileFromRow(Map<String, dynamic> row) {
    final avatarUrl = row['avatar_url'] as String? ?? '';
    final avatarAsset = row['avatar_asset'] as String? ?? '';
    final displayName = row['name'] as String? ?? 'Fan Hallyu';
    final username = row['username'] as String? ?? '';
    final city = row['city'] as String? ?? '';
    final country = row['country'] as String? ?? '';
    return CommunityProfile(
      id: row['id'] as String? ?? '',
      name: displayName,
      username: username,
      city: city,
      country: country,
      fandom: row['fandom'] as String? ?? '',
      favoriteGroup: row['favorite_group'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      avatarAsset: avatarUrl.isNotEmpty ? avatarUrl : avatarAsset,
      followers: '',
      posts: '',
      colors: const [],
      coverAsset: avatarUrl.isNotEmpty ? avatarUrl : avatarAsset,
    );
  }
}
