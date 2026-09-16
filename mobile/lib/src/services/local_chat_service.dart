import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalChatService {
  const LocalChatService();

  static const _conversationsKey = 'hallyuhub.direct-conversations.v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static const maxMessageLength = 1000;

  bool get usesRealMessages => false;

  Future<List<DirectConversation>> restoreConversations() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_conversationsKey);
    if (stored == null) return [];
    try {
      final conversations = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_conversationFromJson)
          .toList();
      return _sorted(conversations);
    } catch (_) {
      await preferences.remove(_conversationsKey);
      return [];
    }
  }

  Future<void> saveConversations(List<DirectConversation> conversations) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _conversationsKey,
      jsonEncode(conversations.map(_conversationToJson).toList()),
    );
    revision.value++;
  }

  Future<List<DirectMessageRequest>> restoreMessageRequests() async => const [];

  Future<DirectConversation?> acceptMessageRequest(String profileId) async {
    final conversations = await restoreConversations();
    return conversations
        .where((conversation) => conversation.profileId == profileId)
        .firstOrNull;
  }

  Future<void> rejectMessageRequest(String profileId) async {}

  Future<void> blockMessageRequest(String profileId) async {}

  Future<bool> isMessageRequestPending(String profileId) async => false;

  Future<List<DirectConversation>> sendStoryReply({
    required Story story,
    required CommunityProfile recipient,
    required String body,
  }) {
    return _appendMessage(
      profile: recipient,
      message: DirectMessage(
        id: _newId('story-reply'),
        senderId: 'local-user',
        recipientId: recipient.id,
        body: body,
        storyId: story.id,
        storyPreview: _storyPreview(story),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<DirectConversation>> addDemoIncomingStoryReply({
    required Story story,
    required CommunityProfile sender,
    String body = 'Me encantó tu historia ✨',
  }) async {
    final conversations = await restoreConversations();
    final exists = conversations.any(
      (conversation) => conversation.messages.any(
        (message) =>
            message.storyId == story.id &&
            message.senderId == sender.id &&
            !message.isOwn,
      ),
    );
    if (exists) return conversations;
    return _appendMessage(
      profile: sender,
      unreadDelta: 1,
      message: DirectMessage(
        id: _newId('incoming-story-reply'),
        senderId: sender.id,
        recipientId: 'local-user',
        body: body,
        storyId: story.id,
        storyPreview: _storyPreview(story),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<DirectConversation>> sendDirectMessage({
    required DirectConversation conversation,
    required String body,
  }) {
    return _appendMessage(
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
      message: DirectMessage(
        id: _newId('direct-message'),
        senderId: 'local-user',
        recipientId: conversation.profileId,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<DirectConversation>> sendDirectAttachment({
    required DirectConversation conversation,
    required DirectMessageAttachmentDraft attachment,
    String body = '',
  }) {
    return _appendMessage(
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
      message: DirectMessage(
        id: _newId('direct-attachment'),
        senderId: 'local-user',
        recipientId: conversation.profileId,
        body: body,
        mediaType: attachment.mediaType,
        mediaUrl: '',
        fileName: attachment.fileName,
        fileSize: attachment.fileSize,
        mimeType: attachment.mimeType,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<DirectConversation>> addDemoIncomingMessage({
    required CommunityProfile sender,
    required String body,
  }) {
    return _appendMessage(
      profile: sender,
      unreadDelta: 1,
      message: DirectMessage(
        id: _newId('incoming-direct-message'),
        senderId: sender.id,
        recipientId: 'local-user',
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<DirectConversation>> sendCollectionInterest({
    required CollectionItem item,
    required String body,
  }) {
    return _appendMessage(
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
      message: DirectMessage(
        id: _newId('collection-interest'),
        senderId: 'local-user',
        recipientId: item.ownerId,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<DirectConversation>> markRead(String profileId) async {
    final conversations = await restoreConversations();
    final updated = conversations
        .map(
          (conversation) => conversation.profileId == profileId
              ? conversation.copyWith(unreadCount: 0)
              : conversation,
        )
        .toList();
    await saveConversations(updated);
    return _sorted(updated);
  }

  Future<int> unreadCount() async {
    final conversations = await restoreConversations();
    return conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  Future<List<DirectConversation>> _appendMessage({
    required CommunityProfile profile,
    required DirectMessage message,
    int unreadDelta = 0,
  }) async {
    final conversations = await restoreConversations();
    final index = conversations.indexWhere(
      (conversation) => conversation.profileId == profile.id,
    );
    if (index == -1) {
      conversations.add(
        DirectConversation(
          profileId: profile.id,
          name: profile.name,
          username: profile.username,
          avatarAsset: profile.avatarAsset,
          unreadCount: unreadDelta,
          messages: [message],
        ),
      );
    } else {
      final existing = conversations[index];
      conversations[index] = existing.copyWith(
        messages: [...existing.messages, message],
        unreadCount: existing.unreadCount + unreadDelta,
      );
    }
    final sorted = _sorted(conversations);
    await saveConversations(sorted);
    return sorted;
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

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  DirectConversation _conversationFromJson(Map<String, dynamic> json) {
    return DirectConversation(
      profileId: json['profileId'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarAsset: json['avatarAsset'] as String,
      unreadCount: json['unreadCount'] as int? ?? 0,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_messageFromJson)
          .toList(),
    );
  }

  Map<String, dynamic> _conversationToJson(DirectConversation conversation) {
    return {
      'profileId': conversation.profileId,
      'name': conversation.name,
      'username': conversation.username,
      'avatarAsset': conversation.avatarAsset,
      'unreadCount': conversation.unreadCount,
      'messages': conversation.messages.map(_messageToJson).toList(),
    };
  }

  DirectMessage _messageFromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      body: json['body'] as String,
      storyId: json['storyId'] as String? ?? '',
      storyPreview: json['storyPreview'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String? ?? '',
      storageBucket: json['storageBucket'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> _messageToJson(DirectMessage message) {
    return {
      'id': message.id,
      'senderId': message.senderId,
      'recipientId': message.recipientId,
      'body': message.body,
      'storyId': message.storyId,
      'storyPreview': message.storyPreview,
      'mediaType': message.mediaType,
      'mediaUrl': message.mediaUrl,
      'storageBucket': message.storageBucket,
      'storagePath': message.storagePath,
      'fileName': message.fileName,
      'fileSize': message.fileSize,
      'mimeType': message.mimeType,
      'createdAt': message.createdAt.toIso8601String(),
    };
  }
}
