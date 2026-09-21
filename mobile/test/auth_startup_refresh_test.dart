import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/data/demo_data.dart';
import 'package:hallyuhub/src/data/legal_documents.dart';
import 'package:hallyuhub/src/hallyu_hub_app.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/home_screen.dart';
import 'package:hallyuhub/src/services/auth_service.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedAuthService extends LocalAuthService {
  _DelayedAuthService(this.session);

  final Future<AuthUser?> session;

  @override
  Future<AuthUser?> restoreSession() => session;
}

class _CountingPostService extends LocalPostService {
  _CountingPostService({this.failAfterFirst = false});

  final bool failAfterFirst;
  int restoreCalls = 0;

  @override
  bool get usesRealPosts => true;

  @override
  Future<List<HubPost>> restorePosts({
    int limit = 60,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    bool homeFeed = false,
    Set<String> followedAuthorIds = const <String>{},
    Set<String> followedEntityIds = const <String>{},
  }) async {
    restoreCalls++;
    if (failAfterFirst && restoreCalls > 1) {
      throw StateError('refresh failed');
    }
    return [posts.first];
  }

  @override
  Future<Set<String>> restoreLikedPostIds() async => <String>{};

  @override
  Future<Set<String>> restoreSavedPostIds() async => <String>{};
}

AuthUser _acceptedUser() {
  final acceptedAt = DateTime(2026, 9, 20);
  return AuthUser(
    name: 'Session User',
    username: 'session-user',
    email: 'session@example.test',
    avatarAsset: '',
    fandom: 'K-pop',
    termsAcceptedAt: acceptedAt,
    privacyAcceptedAt: acceptedAt,
    communityGuidelinesAcceptedAt: acceptedAt,
    betaNoticeAcceptedAt: acceptedAt,
    legalVersion: hallyuHubLegalVersion,
    birthDate: DateTime(1995, 1, 1),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('session restoration does not render Login while initializing', (
    tester,
  ) async {
    final completer = Completer<AuthUser?>();
    await tester.pumpWidget(
      HallyuHubApp(authService: _DelayedAuthService(completer.future)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('auth-startup-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email')), findsNothing);

    completer.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
  });

  testWidgets('restored authenticated session opens the app after loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      HallyuHubApp(
        authService: _DelayedAuthService(Future.value(_acceptedUser())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-startup-loading')), findsNothing);
    expect(find.byKey(const ValueKey('hallyuhub-shell')), findsOneWidget);
  });

  testWidgets('Home pull-to-refresh reloads the remote feed', (tester) async {
    final postService = _CountingPostService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(postService: postService)),
      ),
    );
    await tester.pumpAndSettle();
    final initialCalls = postService.restoreCalls;

    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-refresh-indicator')),
      findsOneWidget,
    );
    expect(postService.restoreCalls, greaterThan(initialCalls));
  });

  testWidgets('Home keeps visible posts when refresh fails', (tester) async {
    final postService = _CountingPostService(failAfterFirst: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(postService: postService)),
      ),
    );
    await tester.pumpAndSettle();
    final postKey = ValueKey('home-post-${posts.first.id}');
    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(postKey), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(postKey), findsOneWidget);
  });
}
