import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/admin_panel_screen.dart';
import 'package:hallyuhub/src/screens/settings_screen.dart';

AuthUser _user(String role) => AuthUser(
      name: 'QA',
      username: 'qa_$role',
      email: 'qa-$role@example.test',
      avatarAsset: '',
      fandom: 'K-pop',
      role: role,
    );

Widget _settings(AuthUser user) => MaterialApp(
      home: AccountSettingsScreen(
        user: user,
        onUserChanged: (_) async {},
        onPrivateProfileChanged: (_) async {},
        onSignOut: () {},
      ),
    );

void main() {
  testWidgets('normal users do not see the Admin Panel entry', (tester) async {
    await tester.pumpWidget(_settings(_user('user')));
    await tester.pumpAndSettle();
    expect(find.text('Panel Admin'), findsNothing);
  });

  testWidgets('admin and moderator users can open the Admin Panel',
      (tester) async {
    for (final role in ['admin', 'moderator']) {
      await tester.pumpWidget(_settings(_user(role)));
      await tester.pumpAndSettle();
      expect(find.text('Panel Admin'), findsOneWidget);
      await tester.tap(find.text('Panel Admin'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPanelScreen), findsOneWidget);
    }
  });
}
