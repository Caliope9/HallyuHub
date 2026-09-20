import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/user_search_screen.dart';
import 'package:hallyuhub/src/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile search button opens the user search screen', (
    tester,
  ) async {
    const user = AuthUser(
      name: 'Perfil de prueba',
      username: '@profile-search-test',
      email: 'profile-search-test@example.test',
      avatarAsset: '',
      fandom: 'K-pop',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            user: user,
            onUserChanged: (_) async {},
            onPrivateProfileChanged: (_) async {},
            onSignOut: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-user-search-open')));
    await tester.pumpAndSettle();

    expect(find.byType(UserSearchScreen), findsOneWidget);
    expect(find.text('Buscar usuarios'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discover-people-search')),
      findsOneWidget,
    );
  });
}
