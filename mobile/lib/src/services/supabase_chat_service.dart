import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import '../theme/app_theme.dart';
import 'local_chat_service.dart';
import 'media_upload_limits.dart';
import 'supabase_notification_service.dart';

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);

  final String message;

  @override
  String toString() => 'ChatServiceException: $message';
}

class SupabaseChatService extends LocalChatService {
  SupabaseChatService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealMessages => true;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const _messageMediaBucket = 'message_media';
  static const _maxImageBytes = MediaUploadLimits.messageImageBytes;
  static const _maxVideoBytes = MediaUploadLimits.messageVideoBytes;
  static const _messageMediaUploadAttempts = 3;

  @override
  Future<List<DirectConversation>> restoreConversations() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];
    final rows = await _restoreConversationRows(
      orFilter: 'created_by.eq.$currentUserId,recipient_id.eq.$currentUserId',
    );
    final preparedRows = await _rowsWithSignedMessageMedia(
      rows.cast<Map<String, dynamic>>(),
    );
    final conversations = preparedRows
        .cast<Map<String, dynamic>>()
        .where((row) {
          final status = row['request_status'] as String? ?? 'pending';
          return status == 'accepted' || row['created_by'] == currentUserId;
        })
        .map(_conversationFromRow)
        .toList(growable: false);
    return _sorted(conversations);
  }

  @override
  Future<List<DirectMessageRequest>> restoreMessageRequests() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const [];
    final rows = await _restoreConversationRows(
      equals: {'recipient_id': currentUserId, 'request_status': 'pending'},
    );
    final preparedRows = await _rowsWithSignedMessageMedia(
      rows.cast<Map<String, dynamic>>(),
    );
    return preparedRows
        .cast<Map<String, dynamic>>()
        .map(_requestFromRow)
        .toList(growable: false);
  }

  @override
  Future<DirectConversation?> acceptMessageRequest(String profileId) async {
    final currentUserId = _requireUser();
    final row = await _conversationWith(profileId);
    if (row == null || row['recipient_id'] != currentUserId) return null;
    await _client
        .from('conversations')
        .update({'request_status': 'accepted'})
        .eq('id', row['id'] as String);
    await _markConversationRead(row['id'] as String);
    LocalChatService.revision.value++;
    final conversations = await restoreConversations();
    return conversations
        .where((conversation) => conversation.profileId == profileId)
        .firstOrNull;
  }

  @override
  Future<void> rejectMessageRequest(String profileId) async {
    await _updateIncomingRequest(profileId, 'rejected');
  }

  @override
  Future<void> blockMessageRequest(String profileId) async {
    await _updateIncomingRequest(profileId, 'blocked');
  }

  @override
  Future<bool> isMessageRequestPending(String profileId) async {
    final row = await _conversationWith(profileId);
    return row != null && row['request_status'] == 'pending';
  }

  @override
  Future<List<DirectConversation>> sendDirectMessage({
    required DirectConversation conversation,
    required String body,
  }) async {
    return _sendMessageToProfile(
      profile: CommunityProfile(
        id: conversation.profileId,
        name: conversation.name,
        username: conversation.username,
        city: '',
        country: '',
        fandom: '',
        favoriteGroup: '',
        bio: '',
        avatarAsset: conversation.avatarAsset,
        followers: '',
        posts: '',
        colors: const [],
      ),
      body: body,
    );
  }

  @override
  Future<List<DirectConversation>> sendDirectAttachment({
    required DirectConversation conversation,
    required DirectMessageAttachmentDraft attachment,
    String body = '',
  }) async {
    return _sendMessageToProfile(
      profile: CommunityProfile(
        id: conversation.profileId,
        name: conversation.name,
        username: conversation.username,
        city: '',
        country: '',
        fandom: '',
        favoriteGroup: '',
        bio: '',
        avatarAsset: conversation.avatarAsset,
        followers: '',
        posts: '',
        colors: const [],
      ),
      body: body,
      attachment: attachment,
    );
  }

  @override
  Future<List<DirectConversation>> sendStoryReply({
    required Story story,
    required CommunityProfile recipient,
    required String body,
  }) {
    return _sendMessageToProfile(
      profile: recipient,
      body: body,
      storyId: story.id,
      storyPreview: _storyPreview(story),
    );
  }

  @override
  Future<List<DirectConversation>> sendCollectionInterest({
    required CollectionItem item,
    required String body,
  }) {
    return _sendMessageToProfile(
      profile: CommunityProfile(
        id: item.ownerId,
        name: item.ownerName,
        username: item.ownerUsername,
        city: item.city,
        country: item.country,
        fandom: item.groupArtist,
        favoriteGroup: item.groupArtist,
        bio: item.description,
        avatarAsset: item.ownerAvatarAsset,
        followers: '',
        posts: '',
        colors: const [],
      ),
      body: body,
    );
  }

  @override
  Future<List<DirectConversation>> markRead(String profileId) async {
    final row = await _conversationWith(profileId);
    if (row != null) await _markConversationRead(row['id'] as String);
    return restoreConversations();
  }

  @override
  Future<int> unreadCount() async {
    final conversations = await restoreConversations();
    return conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  Future<List<DirectConversation>> _sendMessageToProfile({
    required CommunityProfile profile,
    required String body,
    String storyId = '',
    String storyPreview = '',
    DirectMessageAttachmentDraft? attachment,
  }) async {
    final currentUserId = _requireUser();
    _log('DM_CURRENT_USER', {'userId': currentUserId});
    _log('DM_TARGET_USER', {
      'profileId': profile.id,
      'username': profile.username,
      'name': profile.name,
    });
    final cleaned = body.trim();
    if (cleaned.isEmpty && attachment == null) {
      throw const ChatServiceException('Escribí un mensaje primero.');
    }
    if (cleaned.length > LocalChatService.maxMessageLength) {
      throw const ChatServiceException('El mensaje es demasiado largo.');
    }
    if (profile.id == currentUserId) {
      throw const ChatServiceException('No podés enviarte mensajes a vos.');
    }
    final targetProfileId = await _resolveTargetProfileId(profile);
    if (targetProfileId == currentUserId) {
      throw const ChatServiceException('No podés enviarte mensajes a vos.');
    }
    await _ensureNotBlocked(targetProfileId);
    final conversation = await _ensureConversation(targetProfileId);
    _log('DM_SEND_CONVERSATION_ID', {
      'conversationId': conversation.id,
      'requestStatus': conversation.requestStatus,
    });
    _log('DM_SEND_SENDER_ID', {'senderId': currentUserId});
    _log('DM_SEND_BODY_LENGTH', {'length': cleaned.length});
    _log('DM_SEND_MESSAGE_START', {
      'conversationId': conversation.id,
      'senderId': currentUserId,
      'targetId': targetProfileId,
      'requestStatus': conversation.requestStatus,
      'hasAttachment': attachment != null,
    });
    _StoredMessageMedia? storedMedia;
    try {
      if (attachment != null) {
        storedMedia = await _storeMessageMedia(
          userId: currentUserId,
          conversationId: conversation.id,
          attachment: attachment,
        );
      }
      final messageRow = await _client
          .from('messages')
          .insert({
            'conversation_id': conversation.id,
            'sender_id': currentUserId,
            'body': cleaned,
            'story_id': storyId.isEmpty ? null : storyId,
            'story_preview': storyPreview,
            'media_type': storedMedia?.mediaType ?? '',
            'media_url': storedMedia?.mediaUrl,
            'storage_bucket': storedMedia?.bucket ?? '',
            'storage_path': storedMedia?.path ?? '',
            'file_name': storedMedia?.fileName ?? '',
            'file_size': storedMedia?.fileSize ?? 0,
            'mime_type': storedMedia?.mimeType ?? '',
          })
          .select('id')
          .single();
      await _notifyConversationMembers(
        conversationId: conversation.id,
        senderId: currentUserId,
        messageId: messageRow['id'] as String? ?? '',
        isStoryReply: storyId.isNotEmpty || storyPreview.trim().isNotEmpty,
        preview: cleaned.isNotEmpty ? cleaned : storyPreview,
      );
      _log('DM_SEND_MESSAGE_OK', {
        'conversationId': conversation.id,
        'requestStatus': conversation.requestStatus,
      });
    } catch (error) {
      if (storedMedia != null) {
        unawaited(_cleanupStoredMedia(storedMedia));
      }
      _log('DM_SEND_MESSAGE_ERROR', {
        'conversationId': conversation.id,
        'error': '$error',
      });
      throw _chatError(
        error,
        fallback:
            'No pudimos enviar el mensaje. Probá de nuevo en unos segundos.',
      );
    }
    LocalChatService.revision.value++;
    return restoreConversations();
  }

  Future<void> _notifyConversationMembers({
    required String conversationId,
    required String senderId,
    required String messageId,
    required bool isStoryReply,
    required String preview,
  }) async {
    try {
      final rows = await _client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', senderId);
      final safePreview = preview.trim();
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final recipientId = row['user_id'] as String? ?? '';
        await SupabaseNotificationService.createFromClient(
          client: _client,
          recipientId: recipientId,
          actorId: senderId,
          type: isStoryReply ? 'story_reply' : 'dm_message',
          entityType: 'conversation',
          entityId: conversationId,
          title: isStoryReply ? 'Respondieron tu story' : 'Nuevo mensaje',
          body: isStoryReply
              ? 'Respondieron a tu story.'
              : 'Te enviaron un mensaje.',
          metadata: {
            'message_id': messageId,
            'conversation_id': conversationId,
            'preview': safePreview.length > 160
                ? safePreview.substring(0, 160)
                : safePreview,
          },
          dedupe: true,
        );
      }
    } catch (error) {
      _log('DM_NOTIFICATION_CREATE_ERROR', {
        'conversationId': conversationId,
        'error': '$error',
      });
    }
  }

  Future<_StoredMessageMedia> _storeMessageMedia({
    required String userId,
    required String conversationId,
    required DirectMessageAttachmentDraft attachment,
  }) async {
    final mediaType = attachment.mediaType;
    final mimeType = _normalizedMimeType(attachment);
    final fileSize = attachment.fileSize;
    if (mediaType != 'image' && mediaType != 'video') {
      throw const ChatServiceException('Formato no compatible.');
    }
    if (attachment.bytes.isEmpty || fileSize <= 0) {
      throw const ChatServiceException(
        'El archivo parece estar vacío o no se pudo leer.',
      );
    }
    if (mediaType == 'image' && fileSize > _maxImageBytes) {
      throw const ChatServiceException(
        'Ese archivo es demasiado pesado. Enviá una foto de hasta 10MB o un video de hasta 50MB.',
      );
    }
    if (mediaType == 'video' && fileSize > _maxVideoBytes) {
      throw const ChatServiceException(
        'Ese archivo es demasiado pesado. Enviá una foto de hasta 10MB o un video de hasta 50MB.',
      );
    }
    if (!_mimeAllowed(mediaType, mimeType)) {
      throw const ChatServiceException(
        'Formato no compatible. Probá con JPG, PNG, WEBP, MP4, MOV o WEBM.',
      );
    }
    if (mediaType == 'image' &&
        MediaUploadLimits.detectImageContentType(attachment.bytes) == null) {
      throw const ChatServiceException(
        'Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.',
      );
    }
    final extension = _extensionForMimeType(mimeType);
    final safeName = _safeFileName(attachment.fileName, extension);
    final path =
        '$userId/$conversationId/message_${DateTime.now().microsecondsSinceEpoch}_$safeName';
    _log('DM_MEDIA_UPLOAD_START', {
      'bucket': _messageMediaBucket,
      'path': path,
      'mimeType': mimeType,
      'fileSize': fileSize,
    });
    await _uploadMessageMediaWithRetry(
      path: path,
      bytes: attachment.bytes,
      mimeType: mimeType,
    );
    final signedUrl = await _signedMessageMediaUrl(_messageMediaBucket, path);
    _log('DM_MEDIA_UPLOAD_OK', {'bucket': _messageMediaBucket, 'path': path});
    return _StoredMessageMedia(
      mediaType: mediaType,
      mediaUrl: signedUrl,
      bucket: _messageMediaBucket,
      path: path,
      fileName: safeName,
      fileSize: fileSize,
      mimeType: mimeType,
    );
  }

  Future<void> _uploadMessageMediaWithRetry({
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _messageMediaUploadAttempts; attempt++) {
      try {
        _log('DM_MEDIA_UPLOAD_ATTEMPT', {
          'path': path,
          'attempt': attempt,
          'maxAttempts': _messageMediaUploadAttempts,
        });
        await _client.storage
            .from(_messageMediaBucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: supabase.FileOptions(
                contentType: mimeType,
                upsert: true,
                cacheControl: '3600',
              ),
            );
        return;
      } catch (error) {
        lastError = error;
        _log('DM_MEDIA_UPLOAD_ATTEMPT_ERROR', {
          'path': path,
          'attempt': attempt,
          'error': '$error',
        });
        if (attempt < _messageMediaUploadAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 450 * attempt));
        }
      }
    }
    _log('DM_MEDIA_UPLOAD_ERROR', {'path': path, 'error': '$lastError'});
    throw _chatError(
      lastError ?? 'unknown upload error',
      fallback:
          'No pudimos subir el archivo. Revisá tu conexión e intentá de nuevo.',
    );
  }

  Future<void> _cleanupStoredMedia(_StoredMessageMedia media) async {
    try {
      await _client.storage.from(media.bucket).remove([media.path]);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _restoreConversationRows({
    String? orFilter,
    Map<String, String> equals = const {},
  }) async {
    Future<List<Map<String, dynamic>>> selectRows(String select) async {
      var query = _client.from('conversations').select(select);
      for (final entry in equals.entries) {
        query = query.eq(entry.key, entry.value);
      }
      if (orFilter != null && orFilter.isNotEmpty) {
        query = query.or(orFilter);
      }
      final rows = await query;
      return rows.cast<Map<String, dynamic>>().toList(growable: false);
    }

    try {
      return await selectRows(_conversationSelect);
    } catch (error) {
      _log('DM_CONVERSATION_SELECT_FALLBACK', {'error': '$error'});
      return selectRows(_conversationSelectLegacy);
    }
  }

  Future<List<Map<String, dynamic>>> _rowsWithSignedMessageMedia(
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final prepared = <Map<String, dynamic>>[];
    for (final row in rows) {
      final next = Map<String, dynamic>.of(row);
      final rawMessages = (row['messages'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final messages = <Map<String, dynamic>>[];
      for (final message in rawMessages) {
        final nextMessage = Map<String, dynamic>.of(message);
        final bucket = _string(nextMessage, 'storage_bucket', '');
        final path = _string(nextMessage, 'storage_path', '');
        if (bucket.isNotEmpty && path.isNotEmpty) {
          nextMessage['media_url'] = await _signedMessageMediaUrl(bucket, path);
        }
        messages.add(nextMessage);
      }
      next['messages'] = messages;
      prepared.add(next);
    }
    return prepared;
  }

  Future<String> _signedMessageMediaUrl(String bucket, String path) async {
    if (bucket.isEmpty || path.isEmpty) return '';
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 60 * 60);
    } catch (error) {
      _log('DM_MEDIA_SIGN_ERROR', {
        'bucket': bucket,
        'path': path,
        'error': '$error',
      });
      return '';
    }
  }

  String _normalizedMimeType(DirectMessageAttachmentDraft attachment) {
    final mimeType = attachment.mimeType.trim().toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp' ||
        mimeType == 'video/mp4' ||
        mimeType == 'video/quicktime' ||
        mimeType == 'video/webm') {
      return mimeType;
    }
    final extension = _extensionFromName(attachment.fileName);
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => mimeType,
    };
  }

  bool _mimeAllowed(String mediaType, String mimeType) {
    if (mediaType == 'image') {
      return mimeType == 'image/jpeg' ||
          mimeType == 'image/png' ||
          mimeType == 'image/webp';
    }
    if (mediaType == 'video') {
      return mimeType == 'video/mp4' ||
          mimeType == 'video/quicktime' ||
          mimeType == 'video/webm';
    }
    return false;
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

  String _extensionFromName(String fileName) {
    final clean = fileName.split('?').first.toLowerCase();
    final index = clean.lastIndexOf('.');
    if (index == -1 || index == clean.length - 1) return '';
    return clean.substring(index + 1);
  }

  String _safeFileName(String fileName, String extension) {
    final clean = fileName
        .split('/')
        .last
        .split('\\')
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (clean.isEmpty) return 'media.$extension';
    if (_extensionFromName(clean).isEmpty) return '$clean.$extension';
    return clean;
  }

  Future<void> _updateIncomingRequest(String profileId, String status) async {
    final currentUserId = _requireUser();
    final row = await _conversationWith(profileId);
    if (row == null || row['recipient_id'] != currentUserId) return;
    await _client
        .from('conversations')
        .update({'request_status': status})
        .eq('id', row['id'] as String);
    LocalChatService.revision.value++;
  }

  Future<void> _markConversationRead(String conversationId) async {
    final currentUserId = _requireUser();
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('messages')
        .update({'read_at': now})
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId)
        .filter('read_at', 'is', null);
    await _client
        .from('conversation_members')
        .update({'last_read_at': now})
        .eq('conversation_id', conversationId)
        .eq('user_id', currentUserId);
    LocalChatService.revision.value++;
  }

  Future<void> _ensureNotBlocked(String profileId) async {
    final currentUserId = _requireUser();
    try {
      final rows = await _client
          .from('user_blocks')
          .select('blocker_id,blocked_id')
          .or(
            'and(blocker_id.eq.$currentUserId,blocked_id.eq.$profileId),'
            'and(blocker_id.eq.$profileId,blocked_id.eq.$currentUserId)',
          )
          .limit(1);
      if (rows.isNotEmpty) {
        throw const ChatServiceException(
          'No podés enviar mensajes a este usuario.',
        );
      }
    } on ChatServiceException {
      rethrow;
    } catch (error) {
      _log('DM_BLOCK_CHECK_ERROR', {
        'currentUserId': currentUserId,
        'targetId': profileId,
        'error': '$error',
      });
      if (error.toString().toLowerCase().contains('user_blocks')) {
        throw const ChatServiceException(
          'Falta correr la migración de seguridad en Supabase.',
        );
      }
      throw _chatError(
        error,
        fallback:
            'No pudimos validar esta conversación. Probá de nuevo en unos segundos.',
      );
    }
  }

  Future<_ConversationPointer> _ensureConversation(String profileId) async {
    final existing = await _conversationWith(profileId);
    if (existing != null) {
      var status = existing['request_status'] as String? ?? 'pending';
      _log('DM_OPEN_CONVERSATION_ID', {
        'conversationId': existing['id'],
        'createdBy': existing['created_by'],
        'recipientId': existing['recipient_id'],
      });
      _log('DM_OPEN_CONVERSATION_STATUS', {'requestStatus': status});
      if (status == 'rejected' || status == 'blocked') {
        throw const ChatServiceException(
          'No podés enviar mensajes a este usuario por ahora.',
        );
      }
      final currentUserId = _requireUser();
      if (status == 'pending' && existing['recipient_id'] == currentUserId) {
        await _client
            .from('conversations')
            .update({'request_status': 'accepted'})
            .eq('id', existing['id'] as String);
        status = 'accepted';
      }
      return _ConversationPointer(
        id: existing['id'] as String,
        requestStatus: status,
      );
    }
    final currentUserId = _requireUser();
    final mutual = await _hasMutualFollow(profileId);
    final requestStatus = mutual ? 'accepted' : 'pending';
    _log('DM_CREATE_CONVERSATION_START', {
      'createdBy': currentUserId,
      'recipientId': profileId,
      'requestStatus': requestStatus,
    });
    try {
      await _client.from('conversations').insert({
        'created_by': currentUserId,
        'recipient_id': profileId,
        'request_status': requestStatus,
      });
    } catch (error) {
      _log('DM_CREATE_CONVERSATION_ERROR', {
        'createdBy': currentUserId,
        'recipientId': profileId,
        'error': '$error',
      });
      final retry = await _conversationWith(profileId);
      if (retry != null) {
        return _ConversationPointer(
          id: retry['id'] as String,
          requestStatus: retry['request_status'] as String? ?? 'pending',
        );
      }
      throw _chatError(
        error,
        fallback:
            'No pudimos crear la conversación. Probá de nuevo en unos segundos.',
      );
    }
    final row = await _conversationWith(profileId);
    if (row == null) {
      _log('DM_CREATE_CONVERSATION_ERROR', {
        'createdBy': currentUserId,
        'recipientId': profileId,
        'error': 'conversation_not_readable_after_insert',
      });
      throw const ChatServiceException(
        'No pudimos crear la conversación. Probá de nuevo en unos segundos.',
      );
    }
    _log('DM_CREATE_CONVERSATION_OK', {
      'conversationId': row['id'],
      'requestStatus': row['request_status'],
    });
    _log('DM_OPEN_CONVERSATION_ID', {
      'conversationId': row['id'],
      'createdBy': row['created_by'],
      'recipientId': row['recipient_id'],
    });
    _log('DM_OPEN_CONVERSATION_STATUS', {
      'requestStatus': row['request_status'],
    });
    return _ConversationPointer(
      id: row['id'] as String,
      requestStatus: row['request_status'] as String? ?? 'pending',
    );
  }

  Future<Map<String, dynamic>?> _conversationWith(String profileId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;
    _log('DM_FIND_CONVERSATION_START', {
      'currentUserId': currentUserId,
      'targetId': profileId,
    });
    final rows = await _client
        .from('conversations')
        .select('id,created_by,recipient_id,request_status,created_at')
        .or(
          'and(created_by.eq.$currentUserId,recipient_id.eq.$profileId),'
          'and(created_by.eq.$profileId,recipient_id.eq.$currentUserId)',
        );
    final typedRows = rows.cast<Map<String, dynamic>>();
    typedRows.sort(_compareConversationRows);
    final row = typedRows.isEmpty ? null : typedRows.first;
    _log('DM_FIND_CONVERSATION_RESULT', {
      'currentUserId': currentUserId,
      'targetId': profileId,
      'conversationId': row?['id'] ?? '',
      'requestStatus': row?['request_status'] ?? '',
      'found': row != null,
      'matches': typedRows.length,
    });
    return row;
  }

  int _compareConversationRows(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final statusCompare =
        _conversationStatusRank(
          left['request_status'] as String? ?? 'pending',
        ).compareTo(
          _conversationStatusRank(
            right['request_status'] as String? ?? 'pending',
          ),
        );
    if (statusCompare != 0) return statusCompare;
    return _date(right['created_at']).compareTo(_date(left['created_at']));
  }

  int _conversationStatusRank(String status) {
    switch (status) {
      case 'accepted':
        return 0;
      case 'pending':
        return 1;
      case 'rejected':
        return 2;
      case 'blocked':
        return 3;
    }
    return 4;
  }

  Future<bool> _hasMutualFollow(String profileId) async {
    final currentUserId = _requireUser();
    final rows = await _client
        .from('follows')
        .select('follower_id,following_id')
        .or(
          'and(follower_id.eq.$currentUserId,following_id.eq.$profileId),'
          'and(follower_id.eq.$profileId,following_id.eq.$currentUserId)',
        );
    final pairs = rows.cast<Map<String, dynamic>>();
    final iFollow = pairs.any(
      (row) =>
          row['follower_id'] == currentUserId &&
          row['following_id'] == profileId,
    );
    final followsMe = pairs.any(
      (row) =>
          row['follower_id'] == profileId &&
          row['following_id'] == currentUserId,
    );
    return iFollow && followsMe;
  }

  DirectConversation _conversationFromRow(Map<String, dynamic> row) {
    final currentUserId = _requireUser();
    final otherProfile = _otherProfile(row);
    final messages = _messagesFromRow(row, otherProfile.id);
    final unread = messages
        .where(
          (message) =>
              message.senderId != 'local-user' &&
              _messageUnread(row, message.id),
        )
        .length;
    return DirectConversation(
      profileId: otherProfile.id,
      name: otherProfile.name,
      username: otherProfile.username,
      avatarAsset: otherProfile.avatarAsset,
      messages: messages,
      unreadCount: row['created_by'] == currentUserId ? 0 : unread,
    );
  }

  DirectMessageRequest _requestFromRow(Map<String, dynamic> row) {
    final profile = _otherProfile(row);
    final messages = _messagesFromRow(row, profile.id);
    final latest = messages.lastOrNull;
    return DirectMessageRequest(
      id: row['id'] as String,
      profile: profile,
      message: latest?.body ?? 'Quiere enviarte un mensaje.',
      reason: 'Solicitud de mensaje',
      timeLabel: _relativeTime(latest?.createdAt),
    );
  }

  List<DirectMessage> _messagesFromRow(
    Map<String, dynamic> row,
    String otherProfileId,
  ) {
    final currentUserId = _requireUser();
    final messages =
        ((row['messages'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
          ..sort(
            (a, b) => _date(a['created_at']).compareTo(_date(b['created_at'])),
          ));
    return messages
        .map(
          (message) => _messageFromRow(message, currentUserId, otherProfileId),
        )
        .toList(growable: false);
  }

  DirectMessage _messageFromRow(
    Map<String, dynamic> row,
    String currentUserId,
    String otherProfileId,
  ) {
    final senderId = row['sender_id'] as String? ?? '';
    return DirectMessage(
      id: row['id'] as String? ?? '',
      senderId: senderId == currentUserId ? 'local-user' : senderId,
      recipientId: senderId == currentUserId ? otherProfileId : currentUserId,
      body: row['body'] as String? ?? '',
      storyId: row['story_id'] as String? ?? '',
      storyPreview: row['story_preview'] as String? ?? '',
      mediaType: row['media_type'] as String? ?? '',
      mediaUrl: row['media_url'] as String? ?? '',
      storageBucket: row['storage_bucket'] as String? ?? '',
      storagePath: row['storage_path'] as String? ?? '',
      fileName: row['file_name'] as String? ?? '',
      fileSize: row['file_size'] as int? ?? 0,
      mimeType: row['mime_type'] as String? ?? '',
      createdAt: _date(row['created_at']),
    );
  }

  bool _messageUnread(Map<String, dynamic> conversation, String messageId) {
    final rows = (conversation['messages'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final row = rows.firstWhere(
      (message) => message['id'] == messageId,
      orElse: () => const {},
    );
    return row['read_at'] == null;
  }

  CommunityProfile _otherProfile(Map<String, dynamic> row) {
    final currentUserId = _requireUser();
    final otherKey = row['created_by'] == currentUserId
        ? 'recipient_profile'
        : 'creator_profile';
    final profile = (row[otherKey] as Map?)?.cast<String, dynamic>() ?? {};
    final name = _string(profile, 'name', 'Hallyu Fan');
    final fandom = _string(profile, 'fandom', '');
    final country = _string(profile, 'country', '');
    final region = _string(profile, 'content_region', country);
    return CommunityProfile(
      id: profile['id'] as String? ?? '',
      name: name,
      username: _normalizeUsername(_string(profile, 'username', name)),
      city: region,
      country: country,
      fandom: fandom,
      favoriteGroup: _string(profile, 'favorite_group', ''),
      bio: _string(profile, 'bio', 'Fan de HallyuHub.'),
      avatarAsset: _string(
        profile,
        'avatar_url',
        _string(profile, 'avatar_asset', ''),
      ),
      followers: '',
      posts: '',
      colors: _colorsFor(fandom),
    );
  }

  List<DirectConversation> _sorted(List<DirectConversation> conversations) {
    return [...conversations]..sort((a, b) {
      final aTime =
          a.latestMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.latestMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  String _storyPreview(Story story) {
    if (story.title.trim().isNotEmpty) return story.title.trim();
    if (story.text.trim().isNotEmpty) return story.text.trim();
    if (story.detail.trim().isNotEmpty) return story.detail.trim();
    return 'Historia de ${story.name}';
  }

  String _requireUser() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw const ChatServiceException('Necesitás iniciar sesión.');
    }
    return currentUserId;
  }

  Future<String> _resolveTargetProfileId(CommunityProfile profile) async {
    final candidateId = profile.id.trim();
    if (_looksLikeUuid(candidateId)) {
      final rows = await _client
          .from('profiles')
          .select('id')
          .eq('id', candidateId)
          .limit(1);
      if (rows.isNotEmpty) return candidateId;
    }
    final username = profile.username.replaceFirst('@', '').trim();
    if (username.isNotEmpty) {
      final rows = await _client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .limit(1);
      final typedRows = rows.cast<Map<String, dynamic>>();
      if (typedRows.isNotEmpty) {
        return typedRows.first['id'] as String;
      }
    }
    throw const ChatServiceException('No se encontró el usuario destino.');
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  ChatServiceException _chatError(Object error, {required String fallback}) {
    final text = error.toString().toLowerCase();
    if (text.contains('42501') ||
        text.contains('row-level security') ||
        text.contains('permission')) {
      return const ChatServiceException(
        'No tenés permiso para escribir en esta conversación.',
      );
    }
    if (text.contains('media_type') ||
        text.contains('storage_path') ||
        text.contains('message_media')) {
      return const ChatServiceException(
        'Falta activar adjuntos en Supabase. Corré el SQL de message_media.',
      );
    }
    if (text.contains('violates foreign key') ||
        text.contains('invalid input syntax') ||
        text.contains('profiles')) {
      return const ChatServiceException('No se encontró el usuario destino.');
    }
    if (text.contains('failed to fetch') ||
        text.contains('network') ||
        text.contains('connection')) {
      return const ChatServiceException('No pudimos conectar con el servidor.');
    }
    return ChatServiceException(fallback);
  }

  void _log(String event, Map<String, Object?> data) {
    debugPrint(
      '$event ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }

  DateTime _date(dynamic value) {
    return DateTime.tryParse(value as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null ||
        createdAt == DateTime.fromMillisecondsSinceEpoch(0)) {
      return 'Ahora';
    }
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  String _string(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String _normalizeUsername(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '@fan';
    return clean.startsWith('@') ? clean : '@$clean';
  }

  List<Color> _colorsFor(String fandom) {
    final lower = fandom.toLowerCase();
    if (lower.contains('army') || lower.contains('bts')) {
      return [AppTheme.violet, AppTheme.cyan, AppTheme.night];
    }
    if (lower.contains('blink') || lower.contains('blackpink')) {
      return [AppTheme.rose, Colors.pinkAccent, AppTheme.night];
    }
    if (lower.contains('stay') || lower.contains('stray')) {
      return [AppTheme.cyan, AppTheme.teal, AppTheme.night];
    }
    return [AppTheme.rose, AppTheme.cyan, AppTheme.violet];
  }

  static const _conversationSelect =
      'id,created_by,recipient_id,request_status,last_message_at,created_at,'
      'creator_profile:created_by(id,name,username,bio,avatar_asset,avatar_url,'
      'fandom,content_region,favorite_group),'
      'recipient_profile:recipient_id(id,name,username,bio,avatar_asset,'
      'avatar_url,fandom,content_region,favorite_group),'
      'messages(id,sender_id,body,story_id,story_preview,media_type,media_url,'
      'storage_bucket,storage_path,file_name,file_size,mime_type,read_at,'
      'created_at)';

  static const _conversationSelectLegacy =
      'id,created_by,recipient_id,request_status,last_message_at,created_at,'
      'creator_profile:created_by(id,name,username,bio,avatar_asset,avatar_url,'
      'fandom,content_region,favorite_group),'
      'recipient_profile:recipient_id(id,name,username,bio,avatar_asset,'
      'avatar_url,fandom,content_region,favorite_group),'
      'messages(id,sender_id,body,story_id,story_preview,read_at,created_at)';
}

class _ConversationPointer {
  const _ConversationPointer({required this.id, required this.requestStatus});

  final String id;
  final String requestStatus;
}

class _StoredMessageMedia {
  const _StoredMessageMedia({
    required this.mediaType,
    required this.mediaUrl,
    required this.bucket,
    required this.path,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  final String mediaType;
  final String mediaUrl;
  final String bucket;
  final String path;
  final String fileName;
  final int fileSize;
  final String mimeType;
}
