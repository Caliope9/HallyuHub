import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/hallyu_hub_app.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/legal_acceptance_screen.dart';
import 'package:hallyuhub/src/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AuthUser> _register({
  bool betaNoticeAccepted = true,
  String legalVersion = '',
}) async {
  final user = await const LocalAuthService().register(
    name: 'Legal Test',
    username: 'legal-test-${DateTime.now().microsecondsSinceEpoch}',
    email: 'legal-${DateTime.now().microsecondsSinceEpoch}@example.test',
    password: 'legal-password',
    termsAccepted: true,
    privacyAccepted: true,
    communityGuidelinesAccepted: true,
    betaNoticeAccepted: betaNoticeAccepted,
    birthDate: DateTime(1995, 1, 1),
  );
  if (legalVersion.isEmpty) return user;
  return user.copyWith(legalVersion: legalVersion);
}

class _AuthServiceWithBetaStatus implements AuthService {
  _AuthServiceWithBetaStatus(this.status);

  final String status;
  final LocalAuthService delegate = const LocalAuthService();

  @override
  Future<AuthUser?> restoreSession() => delegate.restoreSession();

  @override
  Future<AuthUser> signIn({
    required String login,
    required String password,
    required bool rememberDevice,
  }) => delegate.signIn(
    login: login,
    password: password,
    rememberDevice: rememberDevice,
  );

  @override
  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool communityGuidelinesAccepted = false,
    bool betaNoticeAccepted = false,
    DateTime? birthDate,
  }) => delegate.register(
    name: name,
    username: username,
    email: email,
    password: password,
    termsAccepted: termsAccepted,
    privacyAccepted: privacyAccepted,
    communityGuidelinesAccepted: communityGuidelinesAccepted,
    betaNoticeAccepted: betaNoticeAccepted,
    birthDate: birthDate,
  );

  @override
  Future<void> saveUser(AuthUser user) => delegate.saveUser(user);

  @override
  Future<void> savePrivateProfile(bool privateProfile) =>
      delegate.savePrivateProfile(privateProfile);

  @override
  Future<void> saveLegalAcceptance(AuthUser user) =>
      delegate.saveLegalAcceptance(user);

  @override
  Future<void> changePassword({required String newPassword}) =>
      delegate.changePassword(newPassword: newPassword);

  @override
  Future<void> requestEmailChange({required String newEmail}) =>
      delegate.requestEmailChange(newEmail: newEmail);

  @override
  Future<BetaAccessState> ensureBetaAccess(AuthUser user) async =>
      BetaAccessState.fromJson({
        'status': status,
        'user_limit': 100,
        'approved_count': 0,
        'position': status == 'waitlist' ? 1 : null,
      });

  @override
  Future<void> signOut() => delegate.signOut();
}

Future<void> _assertBetaStatusDoesNotGate(
  WidgetTester tester,
  String status,
) async {
  final auth = _AuthServiceWithBetaStatus(status);
  await auth.register(
    name: 'Beta Gate Test',
    username: 'beta-gate-${DateTime.now().microsecondsSinceEpoch}',
    email: 'beta-gate-${DateTime.now().microsecondsSinceEpoch}@example.test',
    password: 'beta-password',
    termsAccepted: true,
    privacyAccepted: true,
    communityGuidelinesAccepted: true,
    betaNoticeAccepted: true,
    birthDate: DateTime(1995, 1, 1),
  );
  await tester.pumpWidget(HallyuHubApp(authService: auth));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('hallyuhub-shell')), findsOneWidget);
  expect(find.byKey(const ValueKey('beta-access-gate-screen')), findsNothing);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('un registro nuevo con cuatro aceptaciones queda completo', () async {
    final user = await _register();
    expect(user.hasAcceptedCurrentLegal, isTrue);
  });

  test('si falta Beta Notice la aceptación queda incompleta', () async {
    final user = await _register(betaNoticeAccepted: false);
    expect(user.hasAcceptedCurrentLegal, isFalse);
    expect(user.betaNoticeAcceptedAt, isNull);
  });

  testWidgets('una cuenta nueva completa no abre la pantalla legal', (
    tester,
  ) async {
    await _register();
    await tester.pumpWidget(const HallyuHubApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hallyuhub-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-acceptance-screen')), findsNothing);
  });

  testWidgets('un estado beta pending no bloquea el acceso', (tester) async {
    await _assertBetaStatusDoesNotGate(tester, 'pending');
  });

  testWidgets('un estado beta waitlisted no bloquea el acceso', (tester) async {
    await _assertBetaStatusDoesNotGate(tester, 'waitlist');
  });

  testWidgets('una cuenta antigua sin Beta Notice abre la pantalla legal', (
    tester,
  ) async {
    await _register(betaNoticeAccepted: false);
    await tester.pumpWidget(const HallyuHubApp());
    await tester.pumpAndSettle();

    expect(find.byType(LegalAcceptanceScreen), findsOneWidget);
  });

  testWidgets('una versión legal desactualizada abre la pantalla legal', (
    tester,
  ) async {
    final user = await _register();
    await const LocalAuthService().saveUser(user.copyWith(legalVersion: 'old'));
    await tester.pumpWidget(const HallyuHubApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('legal-acceptance-screen')),
      findsOneWidget,
    );
  });

  testWidgets('un fallo de persistencia mantiene el guard legal visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final user = await _register(betaNoticeAccepted: false);
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAcceptanceScreen(
          user: user,
          onAccepted: (_) async => throw const AuthException('save failed'),
          onSignOut: () async {},
        ),
      ),
    );
    for (final id in ['terms', 'privacy', 'community', 'beta_notice']) {
      final checkbox = find.byKey(ValueKey('legal-checkbox-$id'));
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
    }
    await tester.tap(find.byKey(const ValueKey('legal-accept-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(LegalAcceptanceScreen), findsOneWidget);
  });
}
