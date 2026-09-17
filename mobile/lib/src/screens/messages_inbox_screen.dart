import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/demo_data.dart';
import '../models.dart';
import '../services/local_chat_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_safety_service.dart';
import '../services/local_story_service.dart';
import '../services/media_upload_limits.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hub_avatar.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/post_video_player.dart';
import '../widgets/safety_report_sheet.dart';
import 'public_profile_screen.dart';

class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({
    super.key,
    this.chatService = const LocalChatService(),
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.embedded = false,
    this.resetSignal = 0,
    this.onNotifications,
    this.notificationBadgeCount = 0,
  });

  final LocalChatService chatService;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;
  final bool embedded;
  final int resetSignal;
  final VoidCallback? onNotifications;
  final int notificationBadgeCount;

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  List<DirectConversation> _conversations = [];
  late List<DirectMessageRequest> _requests;
  bool _loading = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requests = List<DirectMessageRequest>.of(_demoMessageRequests);
    LocalChatService.revision.addListener(_restore);
    _restore();
  }

  @override
  void dispose() {
    LocalChatService.revision.removeListener(_restore);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessagesInboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) _resetToTop();
  }

  void _resetToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _restore() async {
    List<DirectConversation> conversations;
    List<DirectMessageRequest> requests;
    try {
      conversations = await widget.chatService.restoreConversations();
      requests = widget.chatService.usesRealMessages
          ? await widget.chatService.restoreMessageRequests()
          : _requests;
    } catch (_) {
      conversations = const [];
      requests = widget.chatService.usesRealMessages ? const [] : _requests;
      if (mounted) {
        _showSnack(
          'No pudimos cargar tus mensajes. Revisá conexión y probá de nuevo.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _open(DirectConversation conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DirectChatScreen(
          profile: _profileFromConversation(conversation),
          chatService: widget.chatService,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
        ),
      ),
    );
    await _restore();
  }

  Future<DirectConversation?> _moveRequestToInbox(
    DirectMessageRequest request,
  ) async {
    final conversations = widget.chatService.usesRealMessages
        ? await _acceptRealRequest(request)
        : await widget.chatService.addDemoIncomingMessage(
            sender: request.profile,
            body: request.message,
          );
    if (!mounted) return null;
    setState(() {
      _requests.removeWhere((item) => item.id == request.id);
      _conversations = conversations;
      _loading = false;
    });
    return conversations
        .where((conversation) => conversation.profileId == request.profile.id)
        .firstOrNull;
  }

  Future<void> _acceptRequest(DirectMessageRequest request) async {
    await _moveRequestToInbox(request);
    _showSnack('Solicitud aceptada');
  }

  Future<void> _replyRequest(DirectMessageRequest request) async {
    final conversation = await _moveRequestToInbox(request);
    if (conversation == null || !mounted) return;
    await _open(conversation);
  }

  Future<void> _rejectRequest(DirectMessageRequest request) async {
    if (widget.chatService.usesRealMessages) {
      await widget.chatService.rejectMessageRequest(request.profile.id);
    }
    if (!mounted) return;
    setState(() => _requests.removeWhere((item) => item.id == request.id));
    _showSnack('Solicitud eliminada');
  }

  Future<void> _blockRequest(DirectMessageRequest request) async {
    if (widget.chatService.usesRealMessages) {
      await widget.chatService.blockMessageRequest(request.profile.id);
    }
    if (!mounted) return;
    setState(() => _requests.removeWhere((item) => item.id == request.id));
    _showSnack('${request.profile.name} quedó bloqueado');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _openRequest(DirectMessageRequest request) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MessageRequestDetailSheet(
        request: request,
        onAccept: () {
          Navigator.of(sheetContext).pop();
          unawaited(_acceptRequest(request));
        },
        onReply: () {
          Navigator.of(sheetContext).pop();
          unawaited(_replyRequest(request));
        },
        onReject: () {
          Navigator.of(sheetContext).pop();
          unawaited(_rejectRequest(request));
        },
        onBlock: () {
          Navigator.of(sheetContext).pop();
          unawaited(_blockRequest(request));
        },
      ),
    );
  }

  Future<void> _openRequestsPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MessageRequestsPanel(
        requests: _requests,
        onOpen: (request) {
          Navigator.of(sheetContext).pop();
          unawaited(_openRequest(request));
        },
        onAccept: (request) {
          Navigator.of(sheetContext).pop();
          unawaited(_acceptRequest(request));
        },
        onReject: (request) {
          Navigator.of(sheetContext).pop();
          unawaited(_rejectRequest(request));
        },
      ),
    );
  }

  Future<void> _openNewMessagePanel() async {
    final controller = TextEditingController();
    var results = <CommunityProfile>[];
    var loading = false;
    var seeded = false;
    var searchEpoch = 0;

    Future<void> search(StateSetter setSheetState, [String query = '']) async {
      final epoch = ++searchEpoch;
      setSheetState(() => loading = true);
      try {
        final profiles = await widget.followService.restoreProfiles(
          query: query,
          limit: 30,
        );
        if (!mounted || epoch != searchEpoch) return;
        setSheetState(() {
          results = profiles;
          loading = false;
        });
      } catch (error) {
        debugPrint('MESSAGE_NEW_CHAT_ERROR query=$query error=$error');
        if (!mounted || epoch != searchEpoch) return;
        setSheetState(() {
          results = const [];
          loading = false;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!seeded) {
              seeded = true;
              unawaited(search(setSheetState));
            }
            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.38,
              maxChildSize: 0.92,
              builder: (context, scrollController) => Container(
                decoration: BoxDecoration(
                  color: AppTheme.nightSoft,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nuevo mensaje',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) => search(setSheetState, value),
                      onChanged: (value) {
                        if (value.trim().length >= 2) {
                          unawaited(search(setSheetState, value));
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, usuario o fandom',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              search(setSheetState, controller.text),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (results.isEmpty)
                      const _EmptyNewMessageSearch()
                    else
                      for (final profile in results) ...[
                        _NewMessageProfileTile(
                          profile: profile,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) => DirectChatScreen(
                                    profile: profile,
                                    chatService: widget.chatService,
                                    followService: widget.followService,
                                    postService: widget.postService,
                                    storyService: widget.storyService,
                                    dropService: widget.dropService,
                                    fancamService: widget.fancamService,
                                    safetyService: widget.safetyService,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<List<DirectConversation>> _acceptRealRequest(
    DirectMessageRequest request,
  ) async {
    final accepted = await widget.chatService.acceptMessageRequest(
      request.profile.id,
    );
    final conversations = await widget.chatService.restoreConversations();
    if (accepted == null) return conversations;
    return conversations;
  }

  CommunityProfile _profileFromConversation(DirectConversation conversation) {
    return CommunityProfile(
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
    );
  }

  Widget _conversationCard(DirectConversation conversation) {
    final lastMessage = conversation.latestMessage;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            conversation.unreadCount > 0
                ? AppTheme.violet.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.055),
            AppTheme.panel.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: conversation.unreadCount > 0
              ? AppTheme.rose.withValues(alpha: 0.28)
              : AppTheme.stroke.withValues(alpha: 0.7),
        ),
        boxShadow: conversation.unreadCount > 0
            ? [
                BoxShadow(
                  color: AppTheme.rose.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('dm-conversation-${conversation.profileId}'),
          onTap: () => _open(conversation),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                HubAvatar(
                  asset: conversation.avatarAsset,
                  size: 48,
                  isLive: conversation.unreadCount > 0,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lastMessage == null
                            ? 'Iniciá una conversación'
                            : lastMessage.repliesToStory
                            ? lastMessage.isOwn
                                  ? 'Respondiste a su historia: ${lastMessage.previewText}'
                                  : 'Respondió a tu historia: ${lastMessage.previewText}'
                            : lastMessage.previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (conversation.unreadCount > 0)
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 25,
                      minHeight: 25,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.rose, AppTheme.violet],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.rose.withValues(alpha: 0.28),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppTheme.cyan,
              strokeWidth: 2.6,
            ),
          )
        : ListView(
            key: const ValueKey('dm-inbox'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              const HallyFeatureTip(
                featureId: 'messages_intro',
                title: 'Mensajes privados 💌',
                message:
                    'Chateá con otros fans respetando tus preferencias de privacidad.',
                mascotAsset: 'assets/brand/hally_mascot_wave_transparent.png',
              ),
              if (_conversations.isNotEmpty) ...[
                const _InboxSectionTitle('Chats'),
                const SizedBox(height: 8),
                for (final conversation in _conversations) ...[
                  _conversationCard(conversation),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                const _InboxSectionTitle('Chats'),
                const SizedBox(height: 8),
                const _NoAcceptedChatsYet(),
              ],
            ],
          );
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tus chats',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Conversaciones con otros fans',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _NewMessageChip(onTap: _openNewMessagePanel),
                const SizedBox(width: 8),
                _MessageRequestsChip(
                  count: _requests.length,
                  onTap: _openRequestsPanel,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text(
          'Mensajes',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (widget.onNotifications != null)
            _InboxNotificationsButton(
              count: widget.notificationBadgeCount,
              onTap: widget.onNotifications!,
            ),
          IconButton(
            onPressed: _openNewMessagePanel,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Nuevo mensaje',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _MessageRequestsChip(
                count: _requests.length,
                onTap: _openRequestsPanel,
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _InboxNotificationsButton extends StatelessWidget {
  const _InboxNotificationsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const ValueKey('messages-notifications-button'),
          onPressed: onTap,
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notificaciones',
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.rose,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageRequestsChip extends StatelessWidget {
  const _MessageRequestsChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('message-requests-chip'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 7, 8, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                AppTheme.violet.withValues(alpha: 0.22),
                AppTheme.cyan.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_unread_chat_alt_outlined,
                size: 15,
                color: count > 0 ? AppTheme.cyan : Colors.white70,
              ),
              const SizedBox(width: 6),
              const Text(
                'Solicitudes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.rose,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.rose.withValues(alpha: 0.26),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewMessageChip extends StatelessWidget {
  const _NewMessageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      key: const ValueKey('new-message-chip'),
      onPressed: onTap,
      icon: const Icon(Icons.add_comment_outlined, size: 18),
      tooltip: 'Nuevo mensaje',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.cyan.withValues(alpha: 0.12),
        foregroundColor: AppTheme.cyan,
      ),
    );
  }
}

class _EmptyNewMessageSearch extends StatelessWidget {
  const _EmptyNewMessageSearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        'Buscá fans por nombre, usuario, país, fandom o grupo favorito para empezar una conversación.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NewMessageProfileTile extends StatelessWidget {
  const _NewMessageProfileTile({required this.profile, required this.onTap});

  final CommunityProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              HubAvatar(asset: profile.avatarAsset, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.username} · ${profile.fandom}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRequestsPanel extends StatelessWidget {
  const _MessageRequestsPanel({
    required this.requests,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
  });

  final List<DirectMessageRequest> requests;
  final ValueChanged<DirectMessageRequest> onOpen;
  final ValueChanged<DirectMessageRequest> onAccept;
  final ValueChanged<DirectMessageRequest> onReject;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.violet.withValues(alpha: 0.28),
                blurRadius: 34,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.rose.withValues(alpha: 0.5),
                          AppTheme.cyan.withValues(alpha: 0.38),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.mark_unread_chat_alt_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Solicitudes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.rose.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${requests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Mensajes de personas que todavia no estan en tus chats.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (requests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Text(
                    'No tenes solicitudes pendientes.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                for (final request in requests) ...[
                  _MessageRequestCard(
                    request: request,
                    onOpen: () => onOpen(request),
                    onAccept: () => onAccept(request),
                    onReject: () => onReject(request),
                  ),
                  if (request != requests.last) const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

final _demoMessageRequests = <DirectMessageRequest>[
  DirectMessageRequest(
    id: 'request-cami',
    profile: demoProfileById('demo-cami'),
    message:
        'Hola, vi tu wishlist de photocards. Creo que tengo una que buscás.',
    reason: 'No la seguís todavía',
    timeLabel: 'Ahora',
  ),
  DirectMessageRequest(
    id: 'request-nico',
    profile: demoProfileById('demo-nico'),
    message: '¿Seguís buscando trades de TWICE en Córdoba?',
    reason: 'Contacto de comunidad',
    timeLabel: '12 min',
  ),
  DirectMessageRequest(
    id: 'request-agus',
    profile: demoProfileById('demo-agus'),
    message: 'Estamos armando random play dance este finde, ¿te sumás?',
    reason: 'Actividad cerca tuyo',
    timeLabel: '1 h',
  ),
];

class _InboxSectionTitle extends StatelessWidget {
  const _InboxSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MessageRequestCard extends StatelessWidget {
  const _MessageRequestCard({
    required this.request,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
  });

  final DirectMessageRequest request;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.night.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('message-request-${request.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              HubAvatar(
                asset: request.profile.avatarAsset,
                size: 44,
                isLive: request.profile.online,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          request.timeLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.cyan.withValues(alpha: 0.86),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onReject,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.6,
                            ),
                            minimumSize: const Size(0, 30),
                          ),
                          child: const Text('Rechazar'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: onAccept,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.rose,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Aceptar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRequestDetailSheet extends StatelessWidget {
  const _MessageRequestDetailSheet({
    required this.request,
    required this.onAccept,
    required this.onReply,
    required this.onReject,
    required this.onBlock,
  });

  final DirectMessageRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReply;
  final VoidCallback onReject;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                HubAvatar(
                  asset: request.profile.avatarAsset,
                  size: 58,
                  isLive: request.profile.online,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _messageProfileSubtitle(request.profile),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                request.message,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply_rounded),
                    label: const Text('Responder'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Rechazar'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onBlock,
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Bloquear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _messageProfileSubtitle(CommunityProfile profile) {
  final city = profile.city.trim();
  return city.isEmpty ? profile.username : '${profile.username} · $city';
}

class _NoAcceptedChatsYet extends StatelessWidget {
  const _NoAcceptedChatsYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'Tus conversaciones van a aparecer acá cuando empieces a hablar con otros fans.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.profile,
    this.chatService = const LocalChatService(),
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.safetyService = const LocalSafetyService(),
    this.storeProfileService = const LocalStoreProfileService(),
  });

  final CommunityProfile profile;
  final LocalChatService chatService;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalSafetyService safetyService;
  final StoreProfileService storeProfileService;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _maxVideoBytes = 50 * 1024 * 1024;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  DirectConversation? _conversation;
  DirectMessageAttachmentDraft? _pendingAttachment;
  bool _loading = true;
  bool _sending = false;
  bool _pickingAttachment = false;
  bool _interactionBlocked = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    List<DirectConversation> conversations;
    var interactionBlocked = false;
    try {
      interactionBlocked = await widget.safetyService.isInteractionBlocked(
        widget.profile.id,
      );
      conversations = await widget.chatService.markRead(widget.profile.id);
    } catch (_) {
      conversations = const [];
      if (mounted) {
        _showSnack(
          'No pudimos abrir esta conversación. Probá de nuevo en unos segundos.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _conversation = _conversationForProfile(conversations);
      _interactionBlocked = interactionBlocked;
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_pickingAttachment) {
      _showSnack('Esperá a que terminemos de preparar el archivo.');
      return;
    }
    if (_interactionBlocked) {
      _showSnack('No podés escribir en esta conversación.');
      return;
    }
    final body = _controller.text.trim();
    final attachment = _pendingAttachment;
    if (body.isEmpty && attachment == null) return;
    final conversation =
        _conversation ??
        DirectConversation(
          profileId: widget.profile.id,
          name: widget.profile.name,
          username: widget.profile.username,
          avatarAsset: widget.profile.avatarAsset,
          messages: const [],
        );
    _controller.clear();
    setState(() {
      _sending = true;
      _pendingAttachment = null;
    });
    List<DirectConversation> conversations;
    try {
      conversations = attachment == null
          ? await widget.chatService.sendDirectMessage(
              conversation: conversation,
              body: body,
            )
          : await widget.chatService.sendDirectAttachment(
              conversation: conversation,
              attachment: attachment,
              body: body,
            );
    } catch (error) {
      if (!mounted) return;
      _controller.text = body;
      setState(() {
        _pendingAttachment = attachment;
      });
      _showSnack(_friendlyError(error));
      setState(() => _sending = false);
      return;
    }
    if (!mounted) return;
    final sentConversation = _conversationForProfile(conversations);
    setState(() {
      _conversation = sentConversation;
      _sending = false;
    });
    if (widget.chatService.usesRealMessages &&
        sentConversation != null &&
        await widget.chatService.isMessageRequestPending(
          sentConversation.profileId,
        )) {
      _showSnack('Enviado como solicitud de mensaje');
    }
    _scrollToBottom();
  }

  Future<void> _openAttachmentSheet() async {
    if (_sending || _pickingAttachment) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AttachmentSourceSheet(
        onPhoto: () {
          Navigator.of(sheetContext).pop();
          unawaited(_pickAttachment(isVideo: false));
        },
        onVideo: () {
          Navigator.of(sheetContext).pop();
          unawaited(_pickAttachment(isVideo: true));
        },
      ),
    );
  }

  Future<void> _pickAttachment({required bool isVideo}) async {
    if (_sending || _pickingAttachment) return;
    setState(() => _pickingAttachment = true);
    var stage = 'picker';
    try {
      _logAttachmentStep('PICKER_START', {
        'mediaType': isVideo ? 'video' : 'image',
      });
      final file = isVideo
          ? await _picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 60),
            )
          : await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 88,
            );
      if (file == null) {
        _logAttachmentStep('PICKER_CANCELLED', {
          'mediaType': isVideo ? 'video' : 'image',
        });
        return;
      }
      final fileName = _fileName(file, isVideo: isVideo);
      var mimeType = _mimeTypeFor(file, isVideo: isVideo);
      final extension = _extensionFromName(fileName);
      final reportedSize = await _safeFileLength(file);
      _logAttachmentStep('PICKED_FILE', {
        'name': fileName,
        'reportedSize': reportedSize ?? 'unknown',
        'mimeType': mimeType,
        'extension': extension.isEmpty ? 'unknown' : extension,
      });
      final preValidationError = _preValidateAttachment(
        isVideo: isVideo,
        fileName: fileName,
        fileSize: reportedSize,
        mimeType: mimeType,
      );
      if (preValidationError != null) {
        _logAttachmentStep('VALIDATE_ERROR', {
          'stage': 'pre_read',
          'message': preValidationError,
        });
        _showSnack(preValidationError);
        return;
      }
      stage = 'read bytes';
      _logAttachmentStep('READ_START', {'name': fileName});
      final bytes = await file.readAsBytes().timeout(
        const Duration(seconds: 45),
      );
      final fileSize = bytes.lengthInBytes;
      _logAttachmentStep('READ_OK', {'name': fileName, 'size': fileSize});
      if (!isVideo) {
        final detectedMime = MediaUploadLimits.detectImageContentType(bytes);
        if (detectedMime != null) mimeType = detectedMime;
      }
      stage = 'validate';
      final validationError = _validateAttachment(
        isVideo: isVideo,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
      );
      if (validationError != null) {
        _logAttachmentStep('VALIDATE_ERROR', {
          'stage': 'after_read',
          'message': validationError,
          'size': fileSize,
          'mimeType': mimeType,
          'extension': extension.isEmpty ? 'unknown' : extension,
        });
        _showSnack(validationError);
        return;
      }
      _logAttachmentStep('VALIDATE_OK', {
        'name': fileName,
        'size': fileSize,
        'mimeType': mimeType,
      });
      if (!mounted) return;
      setState(() {
        _pendingAttachment = DirectMessageAttachmentDraft(
          mediaType: isVideo ? 'video' : 'image',
          bytes: bytes,
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
        );
      });
    } on TimeoutException catch (error) {
      debugPrint('DM_ATTACHMENT_READ_TIMEOUT stage=$stage error=$error');
      if (!mounted) return;
      _showSnack('No pudimos leer el archivo a tiempo. Probá de nuevo.');
    } catch (error) {
      debugPrint('DM_ATTACHMENT_ERROR stage=$stage error=$error');
      if (!mounted) return;
      if (stage == 'picker') {
        _showSnack('No pudimos abrir el selector de archivos. Probá de nuevo.');
      } else if (stage == 'read bytes') {
        _showSnack('No pudimos leer ese archivo. Probá con otra foto o video.');
      } else {
        _showSnack(
          'No pudimos preparar ese archivo. Probá con otra foto o video.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  String? _preValidateAttachment({
    required bool isVideo,
    required String fileName,
    required int? fileSize,
    required String mimeType,
  }) {
    final extension = _extensionFromName(fileName);
    if (_isUnsupportedAppleImage(extension, mimeType)) {
      return 'Ese formato no es compatible. Probá enviarla como JPG o PNG.';
    }
    if (fileSize != null) {
      if (isVideo && fileSize > _maxVideoBytes) {
        return 'Ese archivo es demasiado pesado. Enviá una foto de hasta 10MB o un video de hasta 50MB.';
      }
      if (!isVideo && fileSize > _maxImageBytes) {
        return 'Ese archivo es demasiado pesado. Enviá una foto de hasta 10MB o un video de hasta 50MB.';
      }
    }
    if (!isVideo) return null;
    final validMime =
        mimeType == 'video/mp4' ||
        mimeType == 'video/quicktime' ||
        mimeType == 'video/webm';
    final validExtension =
        extension == 'mp4' || extension == 'mov' || extension == 'webm';
    if (!validMime && !validExtension) {
      return 'Formato no compatible. Probá con JPG, PNG, WEBP, MP4, MOV o WEBM.';
    }
    return null;
  }

  String? _validateAttachment({
    required bool isVideo,
    required String fileName,
    required int fileSize,
    required String mimeType,
  }) {
    if (fileSize <= 0) {
      return 'El archivo parece estar vacío o no se pudo leer.';
    }
    if (isVideo && fileSize > _maxVideoBytes) {
      return 'Ese archivo es demasiado pesado. Enviá una foto de hasta 10MB o un video de hasta 50MB.';
    }
    if (!isVideo && fileSize > _maxImageBytes) {
      return 'Ese archivo es demasiado pesado. Enviá una foto de hasta 10MB o un video de hasta 50MB.';
    }
    final extension = _extensionFromName(fileName);
    if (_isUnsupportedAppleImage(extension, mimeType)) {
      return 'Ese formato no es compatible. Probá enviarla como JPG o PNG.';
    }
    if (isVideo) {
      final validMime =
          mimeType == 'video/mp4' ||
          mimeType == 'video/quicktime' ||
          mimeType == 'video/webm';
      final validExtension =
          extension == 'mp4' || extension == 'mov' || extension == 'webm';
      if (!validMime && !validExtension) {
        return 'Formato no compatible. Probá con JPG, PNG, WEBP, MP4, MOV o WEBM.';
      }
      return null;
    }
    final validMime =
        mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp';
    final validExtension =
        extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
    if (!validMime && !validExtension) {
      return 'Formato no compatible. Probá con JPG, PNG, WEBP, MP4, MOV o WEBM.';
    }
    return null;
  }

  String _mimeTypeFor(XFile file, {required bool isVideo}) {
    final explicit = file.mimeType?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final extension = _extensionFromName(file.name);
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'application/octet-stream',
    };
  }

  String _fileName(XFile file, {required bool isVideo}) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final extension = isVideo ? 'mp4' : 'jpg';
    return 'dm_${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  String _extensionFromName(String fileName) {
    final clean = fileName.split('?').first.toLowerCase();
    final index = clean.lastIndexOf('.');
    if (index == -1 || index == clean.length - 1) return '';
    return clean.substring(index + 1);
  }

  bool _isUnsupportedAppleImage(String extension, String mimeType) {
    return extension == 'heic' ||
        extension == 'heif' ||
        mimeType == 'image/heic' ||
        mimeType == 'image/heif' ||
        mimeType == 'image/heic-sequence' ||
        mimeType == 'image/heif-sequence';
  }

  Future<int?> _safeFileLength(XFile file) async {
    try {
      return await file.length().timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('DM_ATTACHMENT_LENGTH_ERROR error=$error');
      return null;
    }
  }

  void _logAttachmentStep(String event, Map<String, Object?> data) {
    debugPrint(
      'DM_ATTACHMENT_$event ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    );
  }

  DirectConversation? _conversationForProfile(
    List<DirectConversation> conversations,
  ) {
    final targetUsername = _normalizeUsername(widget.profile.username);
    return conversations
        .where(
          (conversation) =>
              conversation.profileId == widget.profile.id ||
              _normalizeUsername(conversation.username) == targetUsername,
        )
        .firstOrNull;
  }

  String _normalizeUsername(String value) {
    return value.replaceFirst('@', '').trim().toLowerCase();
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          profile: widget.profile,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          chatService: widget.chatService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
        ),
      ),
    );
  }

  Future<void> _reportMessage(DirectMessage message) async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      contentType: 'direct_message',
      contentId: message.id,
      reportedUserId: widget.profile.id,
      title: 'Reportar mensaje',
      metadata: {'conversation_profile_id': widget.profile.id},
    );
    if (!mounted || !sent) return;
    _showSnack('Gracias. Recibimos tu reporte.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.startsWith('ChatServiceException: ')) {
      return message.replaceFirst('ChatServiceException: ', '');
    }
    return 'No pudimos enviar el mensaje. Probá de nuevo en unos segundos.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _conversation?.messages ?? const <DirectMessage>[];
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: _openProfile,
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              HubAvatar(asset: widget.profile.avatarAsset, size: 38),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    widget.profile.username,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? _EmptyChat(profile: widget.profile)
                : ListView.builder(
                    key: const ValueKey('dm-thread'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _MessageBubble(
                      message: messages[index],
                      onReport: messages[index].isOwn
                          ? null
                          : () => _reportMessage(messages[index]),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingAttachment != null)
                    _PendingAttachmentPreview(
                      attachment: _pendingAttachment!,
                      onCancel: _sending
                          ? null
                          : () => setState(() {
                              _pendingAttachment = null;
                            }),
                    ),
                  TextField(
                    key: const ValueKey('dm-message-input'),
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _interactionBlocked
                          ? 'Conversación no disponible'
                          : _pendingAttachment == null
                          ? 'Mensaje privado'
                          : 'Agregar mensaje opcional',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: IconButton(
                        key: const ValueKey('dm-attachment'),
                        onPressed:
                            _sending ||
                                _pickingAttachment ||
                                _interactionBlocked
                            ? null
                            : _openAttachmentSheet,
                        icon: const Icon(Icons.add_rounded),
                        color: AppTheme.rose,
                        tooltip: 'Enviar foto o video',
                      ),
                      suffixIcon: IconButton(
                        key: const ValueKey('dm-send'),
                        onPressed:
                            _sending ||
                                _pickingAttachment ||
                                _interactionBlocked
                            ? null
                            : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        color: AppTheme.cyan,
                        tooltip: 'Enviar mensaje privado',
                      ),
                    ),
                  ),
                  if (_sending && _pendingAttachment == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        'Subiendo archivo...',
                        style: TextStyle(
                          color: AppTheme.cyan.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (_pickingAttachment)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        'Preparando archivo...',
                        style: TextStyle(
                          color: AppTheme.cyan.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet({required this.onPhoto, required this.onVideo});

  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enviar archivo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AttachmentOption(
              icon: Icons.image_rounded,
              title: 'Foto',
              subtitle: 'JPG, PNG o WEBP hasta 10 MB',
              onTap: onPhoto,
            ),
            const SizedBox(height: 10),
            _AttachmentOption(
              icon: Icons.play_circle_fill_rounded,
              title: 'Video',
              subtitle: 'MP4, MOV o WEBM hasta 60 segundos',
              onTap: onVideo,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.cyan, AppTheme.violet, AppTheme.rose],
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.attachment,
    required this.onCancel,
  });

  final DirectMessageAttachmentDraft attachment;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: attachment.isImage
                  ? Image.memory(
                      attachment.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _ImagePreviewFallback(),
                    )
                  : const _VideoPreviewPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.isImage ? 'Foto lista para enviar' : 'Video listo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${attachment.fileName} · ${_formatBytes(attachment.fileSize)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Tocá enviar para subirlo al chat.',
                  style: TextStyle(
                    color: AppTheme.cyan.withValues(alpha: 0.86),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white70,
            tooltip: 'Cancelar adjunto',
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _ImagePreviewFallback extends StatelessWidget {
  const _ImagePreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white.withValues(alpha: 0.08)),
        const Icon(Icons.image_rounded, color: Colors.white70, size: 30),
      ],
    );
  }
}

class _VideoPreviewPlaceholder extends StatelessWidget {
  const _VideoPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.violet.withValues(alpha: 0.72),
                AppTheme.rose.withValues(alpha: 0.42),
              ],
            ),
          ),
        ),
        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onReport});

  final DirectMessage message;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: message.isOwn
              ? AppTheme.violet.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: message.isOwn
                ? AppTheme.cyan.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.repliesToStory)
              Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  message.isOwn
                      ? 'Respondiste a su historia · ${message.storyPreview}'
                      : 'Respondió a tu historia · ${message.storyPreview}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (message.hasMedia)
              Padding(
                padding: EdgeInsets.only(
                  bottom: message.body.trim().isEmpty ? 0 : 8,
                ),
                child: _MessageMedia(message: message),
              ),
            if (message.body.trim().isNotEmpty)
              Text(
                message.body,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (onReport != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: ValueKey('dm-report-${message.id}'),
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Reportar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageMedia extends StatelessWidget {
  const _MessageMedia({required this.message});

  final DirectMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: message.mediaUrl.isEmpty
            ? _UnavailableMedia(label: 'Foto no disponible')
            : Image.network(
                message.mediaUrl,
                width: 260,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const _UnavailableMedia(label: 'No pudimos cargar la foto'),
              ),
      );
    }
    if (message.isVideo) return _MessageVideoBubble(path: message.mediaUrl);
    return const _UnavailableMedia(label: 'Archivo no disponible');
  }
}

class _MessageVideoBubble extends StatefulWidget {
  const _MessageVideoBubble({required this.path});

  final String path;

  @override
  State<_MessageVideoBubble> createState() => _MessageVideoBubbleState();
}

class _MessageVideoBubbleState extends State<_MessageVideoBubble> {
  bool _muted = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 260,
        height: 260,
        child: widget.path.isEmpty
            ? const _UnavailableMedia(label: 'Video no disponible')
            : Stack(
                children: [
                  Positioned.fill(
                    child: PostVideoPlayer(
                      path: widget.path,
                      muted: _muted,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => setState(() => _muted = !_muted),
                        icon: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: _muted ? 'Activar audio' : 'Silenciar',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UnavailableMedia extends StatelessWidget {
  const _UnavailableMedia({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.nightSoft, AppTheme.violet.withValues(alpha: 0.26)],
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.profile});

  final CommunityProfile profile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Todavía no hay mensajes con ${profile.name}. Cuando escribas, la conversación va a quedar acá.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
