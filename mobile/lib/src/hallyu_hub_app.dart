import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'models.dart';
import 'data/discover_data.dart';
import 'screens/auth_screen.dart';
import 'screens/beta_access_screen.dart';
import 'screens/beta_signup_screen.dart';
import 'screens/drops_screen.dart';
import 'screens/fancams_screen.dart';
import 'screens/home_screen.dart';
import 'screens/legal_acceptance_screen.dart';
import 'screens/messages_inbox_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/user_search_screen.dart';
import 'services/auth_service.dart';
import 'services/account_deletion_service.dart';
import 'services/content_moderation_service.dart';
import 'services/beta_signup_service.dart';
import 'services/feedback_report_service.dart';
import 'services/local_chat_service.dart';
import 'services/local_content_category_service.dart';
import 'services/local_drop_service.dart';
import 'services/local_fancam_service.dart';
import 'services/local_follow_service.dart';
import 'services/local_notification_service.dart';
import 'services/local_post_service.dart';
import 'services/local_safety_service.dart';
import 'services/local_story_service.dart';
import 'services/local_user_tag_service.dart';
import 'services/local_artist_tag_service.dart';
import 'services/public_access_links.dart';
import 'services/store_profile_service.dart';
import 'services/video_playback_coordinator.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_mark.dart';
import 'widgets/hallyu_surface.dart';
import 'widgets/hub_avatar.dart';

class HallyuHubApp extends StatefulWidget {
  const HallyuHubApp({
    super.key,
    this.authService = const LocalAuthService(),
    this.postService = const LocalPostService(),
    this.followService = const LocalFollowService(),
    this.storyService = const LocalStoryService(),
    this.chatService = const LocalChatService(),
    this.contentCategoryService = const LocalContentCategoryService(),
    this.userTagService = const LocalUserTagService(),
    this.artistTagService = const LocalArtistTagService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.notificationService = const LocalNotificationService(),
    this.safetyService = const LocalSafetyService(),
    this.betaSignupService = const LocalBetaSignupService(),
    this.feedbackReportService = const LocalFeedbackReportService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.accountDeletionService = const LocalAccountDeletionService(),
    this.contentModerationService = const UnavailableContentModerationService(),
  });

  final AuthService authService;
  final LocalPostService postService;
  final LocalFollowService followService;
  final LocalStoryService storyService;
  final LocalChatService chatService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalNotificationService notificationService;
  final LocalSafetyService safetyService;
  final BetaSignupService betaSignupService;
  final FeedbackReportService feedbackReportService;
  final StoreProfileService storeProfileService;
  final AccountDeletionService accountDeletionService;
  final ContentModerationService contentModerationService;
  @override
  State<HallyuHubApp> createState() => _HallyuHubAppState();
}

class _HallyuHubAppState extends State<HallyuHubApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  AuthUser? _currentUser;
  BetaAccessState? _betaAccess;
  bool _isCheckingBetaAccess = false;
  String? _betaAccessError;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    debugPrint('APP_SESSION_RESTORE_REQUEST');
    final user = await widget.authService.restoreSession();
    if (!mounted || user == null) {
      debugPrint('APP_SESSION_RESTORE_RESULT user=none');
      return;
    }
    debugPrint('APP_SESSION_RESTORE_RESULT user=${user.email}');
    await _activateAuthenticatedUser(user);
  }

  void _handleAuthenticated(AuthUser user) {
    unawaited(_activateAuthenticatedUser(user));
  }

  Future<void> _activateAuthenticatedUser(AuthUser user) async {
    setState(() {
      _currentUser = user;
      _betaAccess = null;
      _betaAccessError = null;
      _isCheckingBetaAccess = true;
    });
    try {
      final access = await widget.authService.ensureBetaAccess(user);
      if (!mounted) return;
      debugPrint(
        'APP_ROUTE_AFTER_AUTH user=${user.email} '
        'beta_status=${access.status.name} legal=${user.hasAcceptedCurrentLegal}',
      );
      setState(() {
        _betaAccess = access;
        _isCheckingBetaAccess = false;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('APP_ROUTE_BETA_ERROR user=${user.email} error=$error');
      setState(() {
        _betaAccessError = error is AuthException
            ? error.message
            : 'No pudimos validar tu acceso anticipado.';
        _isCheckingBetaAccess = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await widget.authService.signOut();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _betaAccess = null;
      _betaAccessError = null;
      _isCheckingBetaAccess = false;
    });
  }

  Future<void> _handleUserChanged(AuthUser user) async {
    await widget.authService.saveUser(user);
    if (!mounted) return;
    final refreshedUser = await widget.authService.restoreSession();
    if (!mounted) return;
    setState(() => _currentUser = refreshedUser ?? user);
  }

  Future<void> _handlePrivateProfileChanged(bool privateProfile) async {
    await widget.authService.savePrivateProfile(privateProfile);
    if (!mounted) return;
    final refreshedUser = await widget.authService.restoreSession();
    if (!mounted) return;
    setState(
      () => _currentUser =
          refreshedUser ??
          _currentUser?.copyWith(privateProfile: privateProfile),
    );
  }

  Future<void> _handleLegalAccepted(AuthUser user) async {
    await widget.authService.saveLegalAcceptance(user);
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    final showingPublicAccess = isPublicAccessPath(Uri.base.path);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      navigatorObservers: [videoPlaybackNavigatorObserver],
      title: 'HallyuHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: showingPublicAccess
          ? BetaSignupScreen(
              key: const ValueKey('public-access-signup-screen'),
              betaSignupService: widget.betaSignupService,
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _currentUser == null
                  ? AuthScreen(
                      key: const ValueKey('auth-screen'),
                      authService: widget.authService,
                      onAuthenticated: _handleAuthenticated,
                    )
                  : _isCheckingBetaAccess
                  ? const BetaAccessLoadingScreen(
                      key: ValueKey('beta-access-loading-screen'),
                    )
                  : _betaAccessError != null ||
                        !(_betaAccess?.isApproved ?? false)
                  ? BetaAccessGateScreen(
                      key: const ValueKey('beta-access-gate-screen'),
                      access: _betaAccess,
                      errorMessage: _betaAccessError,
                      onSignOut: _handleSignOut,
                    )
                  : !_currentUser!.hasAcceptedCurrentLegal
                  ? LegalAcceptanceScreen(
                      key: const ValueKey('legal-acceptance-screen'),
                      user: _currentUser!,
                      onAccepted: _handleLegalAccepted,
                      onSignOut: _handleSignOut,
                    )
                  : HallyuHubShell(
                      key: const ValueKey('hallyuhub-shell'),
                      user: _currentUser!,
                      postService: widget.postService,
                      followService: widget.followService,
                      storyService: widget.storyService,
                      chatService: widget.chatService,
                      contentCategoryService: widget.contentCategoryService,
                      userTagService: widget.userTagService,
                      artistTagService: widget.artistTagService,
                      dropService: widget.dropService,
                      fancamService: widget.fancamService,
                      notificationService: widget.notificationService,
                      safetyService: widget.safetyService,
                      betaSignupService: widget.betaSignupService,
                      feedbackReportService: widget.feedbackReportService,
                      storeProfileService: widget.storeProfileService,
                      accountDeletionService: widget.accountDeletionService,
                      contentModerationService: widget.contentModerationService,
                      onUserChanged: _handleUserChanged,
                      onPrivateProfileChanged: _handlePrivateProfileChanged,
                      onSignOut: _handleSignOut,
                    ),
            ),
    );
  }
}

class HallyuHubShell extends StatefulWidget {
  const HallyuHubShell({
    super.key,
    required this.user,
    required this.postService,
    required this.followService,
    required this.storyService,
    required this.chatService,
    required this.contentCategoryService,
    required this.userTagService,
    required this.artistTagService,
    required this.dropService,
    required this.fancamService,
    required this.notificationService,
    required this.safetyService,
    required this.betaSignupService,
    required this.feedbackReportService,
    required this.storeProfileService,
    required this.accountDeletionService,
    required this.contentModerationService,
    required this.onUserChanged,
    required this.onPrivateProfileChanged,
    required this.onSignOut,
  });

  final AuthUser user;
  final LocalPostService postService;
  final LocalFollowService followService;
  final LocalStoryService storyService;
  final LocalChatService chatService;
  final LocalContentCategoryService contentCategoryService;
  final LocalUserTagService userTagService;
  final LocalArtistTagService artistTagService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalNotificationService notificationService;
  final LocalSafetyService safetyService;
  final BetaSignupService betaSignupService;
  final FeedbackReportService feedbackReportService;
  final StoreProfileService storeProfileService;
  final AccountDeletionService accountDeletionService;
  final ContentModerationService contentModerationService;
  final Future<void> Function(AuthUser user) onUserChanged;
  final Future<void> Function(bool privateProfile) onPrivateProfileChanged;
  final VoidCallback onSignOut;

  @override
  State<HallyuHubShell> createState() => _HallyuHubShellState();
}

class _HallyuHubShellState extends State<HallyuHubShell>
    with WidgetsBindingObserver {
  int selectedIndex = 0;
  double _tabSwipeDistance = 0;
  bool _tabSwipeHandled = false;
  bool _tabSwipeSuppressed = false;
  final _tabResetSignals = List<int>.filled(5, 0);
  DiscoverSection? _requestedSearchSection;
  int _searchSectionRequestSignal = 0;
  List<HallyuNotification> _notifications = const [];
  bool _notificationsLoading = false;

  static const _minimumTabSwipeDistance = 86.0;
  // Home now has a compact intro and quick-access rail above Stories. Keep
  // horizontal gestures in those rails from changing the main tab.
  static const _horizontalRailGuardHeight = 220.0;

  static const titles = [
    'Tu universo K-pop latino',
    'Descubre fandoms',
    'Drops en tendencia',
    'Fancams de fans',
    'Perfil fan',
  ];

  int get _notificationBadge =>
      _notifications.where((notification) => !notification.isRead).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalNotificationService.revision.addListener(_restoreNotifications);
    _restoreNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalNotificationService.revision.removeListener(_restoreNotifications);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _restoreNotifications();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(
          VideoPlaybackCoordinator.pauseActive(
            reason: 'app_lifecycle_${state.name}',
          ),
        );
        return;
    }
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.focused) return;
    unawaited(
      VideoPlaybackCoordinator.pauseActive(reason: 'window_focus_lost'),
    );
  }

  void _selectTab(int index) {
    final nextIndex = index.clamp(0, titles.length - 1);
    if (nextIndex == selectedIndex) return;
    unawaited(
      VideoPlaybackCoordinator.pauseActive(
        reason: 'bottom_tab_${selectedIndex}_to_$nextIndex',
      ),
    );
    setState(() {
      selectedIndex = nextIndex;
      _tabResetSignals[nextIndex]++;
    });
  }

  void _openHomeSearch() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserSearchScreen(
          currentUser: widget.user,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          chatService: widget.chatService,
          contentCategoryService: widget.contentCategoryService,
          userTagService: widget.userTagService,
          artistTagService: widget.artistTagService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
        ),
      ),
    );
  }

  void _openHomeDiscoverSection(DiscoverSection section) {
    unawaited(
      VideoPlaybackCoordinator.pauseActive(reason: 'home_discover_section'),
    );
    setState(() {
      _requestedSearchSection = section;
      _searchSectionRequestSignal++;
      selectedIndex = 1;
      _tabResetSignals[1]++;
    });
  }

  Future<void> _restoreNotifications() async {
    if (_notificationsLoading) return;
    _notificationsLoading = true;
    final shellUser = widget.user.email.isNotEmpty
        ? widget.user.email
        : widget.user.username;
    debugPrint(
      'NOTIFICATIONS_FETCH_START shellUser=$shellUser '
      'serviceReal=${widget.notificationService.usesRealNotifications}',
    );
    try {
      final notifications = await widget.notificationService
          .restoreNotifications();
      if (!mounted) return;
      debugPrint(
        'NOTIFICATIONS_FETCH_COUNT shellUser=$shellUser '
        'count=${notifications.length}',
      );
      setState(() => _notifications = notifications);
    } catch (error) {
      debugPrint('NOTIFICATIONS_FETCH_ERROR shellUser=$shellUser error=$error');
    } finally {
      _notificationsLoading = false;
    }
  }

  Future<void> _markNotificationsRead() async {
    try {
      await widget.notificationService.markAllRead();
      await _restoreNotifications();
    } catch (error) {
      debugPrint('NOTIFICATION_ERROR markRead error=$error');
    }
  }

  Future<void> _openNotificationDestination(
    HallyuNotification notification, {
    bool alreadyInMessages = false,
  }) async {
    try {
      await widget.notificationService.markRead(notification.id);
      await _restoreNotifications();
    } catch (error) {
      debugPrint('NOTIFICATION_ERROR mark single read error=$error');
    }
    if (!mounted) return;

    if (notification.type == 'dm_message' ||
        notification.type == 'story_reply' ||
        notification.entityType == 'conversation') {
      if (!alreadyInMessages) await _openMessages();
      return;
    }

    if (notification.entityType == 'drop' && notification.entityId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DropsScreen(
            user: widget.user,
            dropService: widget.dropService,
            followService: widget.followService,
            postService: widget.postService,
            chatService: widget.chatService,
            storyService: widget.storyService,
            contentCategoryService: widget.contentCategoryService,
            userTagService: widget.userTagService,
            artistTagService: widget.artistTagService,
            fancamService: widget.fancamService,
            safetyService: widget.safetyService,
            storeProfileService: widget.storeProfileService,
            initialDropId: notification.entityId,
            showBackButton: true,
          ),
        ),
      );
      return;
    }

    if (notification.entityType == 'fancam' &&
        notification.entityId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FancamsScreen(
            user: widget.user,
            fancamService: widget.fancamService,
            followService: widget.followService,
            postService: widget.postService,
            chatService: widget.chatService,
            storyService: widget.storyService,
            dropService: widget.dropService,
            contentCategoryService: widget.contentCategoryService,
            userTagService: widget.userTagService,
            artistTagService: widget.artistTagService,
            safetyService: widget.safetyService,
            storeProfileService: widget.storeProfileService,
            initialFancamId: notification.entityId,
            showBackButton: true,
          ),
        ),
      );
      return;
    }

    if (notification.entityType == 'post') {
      _selectTab(4);
      return;
    }

    final actor = notification.actor;
    if (actor != null && actor.id.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            profile: actor,
            currentUser: widget.user,
            followService: widget.followService,
            postService: widget.postService,
            storyService: widget.storyService,
            dropService: widget.dropService,
            fancamService: widget.fancamService,
            chatService: widget.chatService,
            contentCategoryService: widget.contentCategoryService,
            userTagService: widget.userTagService,
            artistTagService: widget.artistTagService,
            safetyService: widget.safetyService,
            storeProfileService: widget.storeProfileService,
          ),
        ),
      );
    }
  }

  Future<void> _openNotifications({bool fromMessages = false}) async {
    await _restoreNotifications();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _BetaNotificationsSheet(
        notifications: _notifications,
        loading: _notificationsLoading,
        onOpen: (notification) {
          Navigator.of(sheetContext).pop();
          _openNotificationDestination(
            notification,
            alreadyInMessages: fromMessages,
          );
        },
        onMarkRead: () {
          Navigator.of(sheetContext).pop();
          _markNotificationsRead();
        },
      ),
    );
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessagesInboxScreen(
          chatService: widget.chatService,
          followService: widget.followService,
          postService: widget.postService,
          storyService: widget.storyService,
          dropService: widget.dropService,
          fancamService: widget.fancamService,
          safetyService: widget.safetyService,
          storeProfileService: widget.storeProfileService,
          onNotifications: () => _openNotifications(fromMessages: true),
          notificationBadgeCount: _notificationBadge,
        ),
      ),
    );
    if (mounted) await _restoreNotifications();
  }

  void _startTabSwipe(DragStartDetails details) {
    _tabSwipeDistance = 0;
    _tabSwipeHandled = false;
    _tabSwipeSuppressed = details.localPosition.dy < _horizontalRailGuardHeight;
  }

  void _trackTabSwipe(DragUpdateDetails details) {
    if (_tabSwipeSuppressed) return;
    if (_tabSwipeHandled) return;
    _tabSwipeDistance += details.primaryDelta ?? 0;
    if (_tabSwipeDistance.abs() < _minimumTabSwipeDistance) return;
    _tabSwipeHandled = true;
    _selectTab(selectedIndex + (_tabSwipeDistance < 0 ? 1 : -1));
  }

  void _finishTabSwipe() {
    _tabSwipeDistance = 0;
    _tabSwipeHandled = false;
    _tabSwipeSuppressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        user: widget.user,
        postService: widget.postService,
        followService: widget.followService,
        storyService: widget.storyService,
        chatService: widget.chatService,
        contentCategoryService: widget.contentCategoryService,
        userTagService: widget.userTagService,
        artistTagService: widget.artistTagService,
        dropService: widget.dropService,
        fancamService: widget.fancamService,
        safetyService: widget.safetyService,
        storeProfileService: widget.storeProfileService,
        resetSignal: _tabResetSignals[0],
        onOpenDiscoverSection: _openHomeDiscoverSection,
      ),
      SearchScreen(
        user: widget.user,
        followService: widget.followService,
        chatService: widget.chatService,
        postService: widget.postService,
        storyService: widget.storyService,
        contentCategoryService: widget.contentCategoryService,
        artistTagService: widget.artistTagService,
        userTagService: widget.userTagService,
        dropService: widget.dropService,
        fancamService: widget.fancamService,
        safetyService: widget.safetyService,
        storeProfileService: widget.storeProfileService,
        resetSignal: _tabResetSignals[1],
        initialSection: _requestedSearchSection,
        sectionRequestSignal: _searchSectionRequestSignal,
      ),
      DropsScreen(
        user: widget.user,
        dropService: widget.dropService,
        followService: widget.followService,
        postService: widget.postService,
        chatService: widget.chatService,
        storyService: widget.storyService,
        contentCategoryService: widget.contentCategoryService,
        userTagService: widget.userTagService,
        artistTagService: widget.artistTagService,
        fancamService: widget.fancamService,
        safetyService: widget.safetyService,
        storeProfileService: widget.storeProfileService,
        resetSignal: _tabResetSignals[2],
        isActive: selectedIndex == 2,
      ),
      FancamsScreen(
        user: widget.user,
        fancamService: widget.fancamService,
        followService: widget.followService,
        postService: widget.postService,
        chatService: widget.chatService,
        storyService: widget.storyService,
        dropService: widget.dropService,
        contentCategoryService: widget.contentCategoryService,
        userTagService: widget.userTagService,
        artistTagService: widget.artistTagService,
        safetyService: widget.safetyService,
        storeProfileService: widget.storeProfileService,
        resetSignal: _tabResetSignals[3],
        isActive: selectedIndex == 3,
      ),
      ProfileScreen(
        user: widget.user,
        postService: widget.postService,
        followService: widget.followService,
        storyService: widget.storyService,
        chatService: widget.chatService,
        contentCategoryService: widget.contentCategoryService,
        userTagService: widget.userTagService,
        artistTagService: widget.artistTagService,
        dropService: widget.dropService,
        fancamService: widget.fancamService,
        safetyService: widget.safetyService,
        feedbackReportService: widget.feedbackReportService,
        onUserChanged: widget.onUserChanged,
        onPrivateProfileChanged: widget.onPrivateProfileChanged,
        onSignOut: widget.onSignOut,
        resetSignal: _tabResetSignals[4],
        storeProfileService: widget.storeProfileService,
        accountDeletionService: widget.accountDeletionService,
        betaSignupService: widget.betaSignupService,
        contentModerationService: widget.contentModerationService,
      ),
    ];

    return Scaffold(
      body: HallyuBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  _TopBar(
                    title: titles[selectedIndex],
                    onSearch: _openHomeSearch,
                    onNotifications: _openNotifications,
                    onMessages: _openMessages,
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('main-tab-swipe-area'),
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _startTabSwipe,
                      onHorizontalDragUpdate: _trackTabSwipe,
                      onHorizontalDragEnd: (_) => _finishTabSwipe(),
                      onHorizontalDragCancel: _finishTabSwipe,
                      child: IndexedStack(
                        index: selectedIndex,
                        children: screens,
                      ),
                    ),
                  ),
                  _HallyuBottomNav(
                    selectedIndex: selectedIndex,
                    onSelected: _selectTab,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HallyuBottomNav extends StatelessWidget {
  const _HallyuBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    _HallyuNavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    _HallyuNavItemData(
      icon: Icons.search_rounded,
      activeIcon: Icons.travel_explore_rounded,
      label: 'Buscar',
    ),
    _HallyuNavItemData(
      icon: Icons.play_circle_outline_rounded,
      activeIcon: Icons.play_circle_fill_rounded,
      label: 'Drops',
    ),
    _HallyuNavItemData(
      icon: Icons.videocam_outlined,
      activeIcon: Icons.videocam_rounded,
      label: 'Fancams',
    ),
    _HallyuNavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 9),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.panelRaised.withValues(alpha: 0.92),
                  AppTheme.panel.withValues(alpha: 0.96),
                  AppTheme.violet.withValues(alpha: 0.11),
                ],
              ),
              border: Border.all(color: AppTheme.stroke.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.rose.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Expanded(
                    child: _HallyuBottomNavItem(
                      item: _items[index],
                      active: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HallyuNavItemData {
  const _HallyuNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _HallyuBottomNavItem extends StatelessWidget {
  const _HallyuBottomNavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _HallyuNavItemData item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = const Color(0xFFB7C0D8).withValues(alpha: 0.68);
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.rose.withValues(alpha: 0.24),
                      AppTheme.violet.withValues(alpha: 0.2),
                      AppTheme.cyan.withValues(alpha: 0.12),
                    ],
                  ),
                ),
              ),
            if (active)
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
                ).createShader(bounds),
                child: Icon(item.activeIcon, size: 22, color: Colors.white),
              )
            else
              Icon(item.icon, size: 22, color: inactiveColor),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item.label,
            maxLines: 1,
            style: TextStyle(
              color: active ? Colors.white : inactiveColor,
              fontSize: 11,
              fontWeight: active ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('bottom-nav-${item.label}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.rose.withValues(alpha: 0.24),
                        AppTheme.cyan.withValues(alpha: 0.18),
                        AppTheme.violet.withValues(alpha: 0.22),
                      ],
                    )
                  : null,
              border: active
                  ? Border.all(color: AppTheme.rose.withValues(alpha: 0.28))
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              const HallyuBrandIcon(size: 44, radiusFactor: 0.25),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HallyuBrandWordmark(fontSize: 20, compact: true),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Buscar',
                child: IconButton(
                  key: const ValueKey('header-search-button'),
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Buscar',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.panelRaised.withValues(
                      alpha: 0.86,
                    ),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Semantics(
                button: true,
                label: 'Notificaciones',
                child: IconButton(
                  key: const ValueKey('header-notifications-button'),
                  onPressed: onNotifications,
                  icon: const Icon(Icons.notifications_none_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.panelRaised.withValues(
                      alpha: 0.86,
                    ),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton.filledTonal(
                key: const ValueKey('header-messages-button'),
                onPressed: onMessages,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                tooltip: 'Mensajes',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.panelRaised.withValues(alpha: 0.86),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BetaNotificationsSheet extends StatelessWidget {
  const _BetaNotificationsSheet({
    required this.notifications,
    required this.loading,
    required this.onOpen,
    required this.onMarkRead,
  });

  final List<HallyuNotification> notifications;
  final bool loading;
  final ValueChanged<HallyuNotification> onOpen;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final hasNotifications = notifications.isNotEmpty;
    final unreadCount = notifications
        .where((notification) => !notification.isRead)
        .length;
    return DraggableScrollableSheet(
      initialChildSize: 0.64,
      minChildSize: 0.34,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.violet.withValues(alpha: 0.24),
              blurRadius: 34,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
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
                const Expanded(
                  child: Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasNotifications)
                  TextButton(
                    onPressed: unreadCount == 0 ? null : onMarkRead,
                    child: const Text('Marcar leídas'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (loading && !hasNotifications)
              const _NotificationLoadingState()
            else if (!hasNotifications)
              const _NotificationEmptyState()
            else
              for (final notification in notifications) ...[
                _NotificationTile(
                  notification: notification,
                  onTap: () => onOpen(notification),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final HallyuNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actor = notification.actor;
    final avatarAsset = actor?.avatarAsset ?? '';
    final icon = _notificationIcon(notification);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: notification.isRead
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.055),
                      Colors.white.withValues(alpha: 0.035),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.rose.withValues(alpha: 0.18),
                      AppTheme.violet.withValues(alpha: 0.16),
                      AppTheme.cyan.withValues(alpha: 0.1),
                    ],
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: notification.isRead
                  ? Colors.white.withValues(alpha: 0.09)
                  : AppTheme.rose.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (avatarAsset.isEmpty)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.rose, AppTheme.cyan],
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    )
                  else
                    HubAvatar(asset: avatarAsset, size: 42),
                  Positioned(
                    right: -4,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.nightSoft,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(icon, color: AppTheme.cyan, size: 12),
                    ),
                  ),
                ],
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
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (notification.isRead
                                        ? Colors.white
                                        : AppTheme.rose)
                                    .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            notification.isRead ? 'Leída' : 'Nueva',
                            style: TextStyle(
                              color: notification.isRead
                                  ? Colors.white.withValues(alpha: 0.62)
                                  : const Color(0xFFFFD1DF),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(notification.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.rose,
                  ),
                ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(HallyuNotification notification) {
    return switch (notification.type) {
      'follow' => Icons.person_add_alt_1_rounded,
      'post_comment' ||
      'drop_comment' ||
      'fancam_comment' => Icons.mode_comment_outlined,
      'post_like' || 'drop_like' || 'fancam_like' => Icons.star_rounded,
      'user_tag' => Icons.alternate_email_rounded,
      'dm_message' => Icons.chat_bubble_outline_rounded,
      'story_reply' => Icons.auto_stories_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.violet.withValues(alpha: 0.22),
            AppTheme.night.withValues(alpha: 0.28),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/brand/hally_mascot_hello.jpeg',
              height: 92,
              width: 92,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu campanita está tranquila.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando alguien te siga, comente, te etiquete o te mande un mensaje, lo vas a ver acá.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cargando notificaciones...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
