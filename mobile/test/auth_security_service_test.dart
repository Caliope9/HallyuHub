import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hallyuhub/src/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'local password change stores only a hash and requires a session',
    () async {
      final service = const LocalAuthService();
      final birthDate = DateTime(DateTime.now().year - 20, 1, 1);
      await service.register(
        name: 'Test User',
        username: '@security-test',
        email: 'security-test@example.test',
        password: 'old-password',
        birthDate: birthDate,
      );

      await service.changePassword(newPassword: 'new-password');
      await service.signOut();
      await expectLater(
        service.signIn(
          login: 'security-test@example.test',
          password: 'old-password',
          rememberDevice: true,
        ),
        throwsA(isA<AuthException>()),
      );
      final signedIn = await service.signIn(
        login: 'security-test@example.test',
        password: 'new-password',
        rememberDevice: true,
      );
      expect(signedIn.email, 'security-test@example.test');

      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('hallyuhub.accounts.v1')!;
      expect(raw, isNot(contains('old-password')));
      expect(raw, isNot(contains('new-password')));
    },
  );

  test(
    'local email change never pretends that confirmation happened',
    () async {
      final service = const LocalAuthService();
      await expectLater(
        service.requestEmailChange(newEmail: 'new@example.test'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('role survives persisted sign-in and session restore', () async {
    final service = const LocalAuthService();
    final registered = await service.register(
      name: 'Admin User',
      username: '@role-test',
      email: 'role-test@example.test',
      password: 'role-password',
      birthDate: DateTime(1995, 1, 1),
    );
    await service.saveUser(registered.copyWith(role: 'admin'));

    expect((await service.restoreSession())?.role, 'admin');
    await service.signOut();

    final signedIn = await service.signIn(
      login: 'role-test@example.test',
      password: 'role-password',
      rememberDevice: true,
    );
    expect(signedIn.role, 'admin');
    expect(signedIn.canAccessAdminPanel, isTrue);
  });
}
