import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'hallyuhub.feature-tip.disabled.artists_intro': true,
      'hallyuhub.feature-tip.disabled.messages_intro': true,
      'auth.session': 'still-signed-in',
      'profile.private': true,
    });
  });

  testWidgets('Settings reset changes only Hally tip flags', (tester) async {
    const user = AuthUser(
      name: 'Fan',
      username: 'fan',
      email: 'fan@example.test',
      avatarAsset: '',
      fandom: 'K-pop',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsScreen(
            user: user,
            onUserChanged: (_) async {},
            onPrivateProfileChanged: (_) async {},
            onSignOut: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-hally-tips')).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-hally-tips-reset-confirm')),
    );
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool('hallyuhub.feature-tip.disabled.artists_intro'),
      isNull,
    );
    expect(
      preferences.getBool('hallyuhub.feature-tip.disabled.messages_intro'),
      isNull,
    );
    expect(preferences.getString('auth.session'), 'still-signed-in');
    expect(preferences.getBool('profile.private'), isTrue);
  });
}
