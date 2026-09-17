import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/home_screen.dart';
import 'package:hallyuhub/src/screens/discover_people_screen.dart';
import 'package:hallyuhub/src/screens/public_profile_screen.dart';

AuthUser _currentUser() => const AuthUser(
  name: 'Mika Hallyu',
  username: '@mika.hallyu',
  email: 'mika@example.test',
  avatarAsset: '',
  fandom: 'ARMY',
);

Widget _screen() => MaterialApp(
  theme: ThemeData.dark(),
  home: DiscoverPeopleScreen(currentUser: _currentUser()),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search finds a username and excludes the current user', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('discover-people-search')),
      '@luna',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('discover-person-demo-luna')),
        matching: find.text('Luna Rivas'),
      ),
      findsOneWidget,
    );
    expect(find.text('@mika.hallyu'), findsNothing);
  });

  testWidgets('search finds display name and shows empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('discover-people-search')),
      'Luna Rivas',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('discover-person-demo-luna')),
        matching: find.text('Luna Rivas'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('discover-people-search')),
      'person-that-does-not-exist',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.text('No encontramos personas con ese nombre.'),
      findsOneWidget,
    );
  });

  testWidgets('follow action updates immediately and profile opens', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    final followButton = find.byKey(
      const ValueKey('discover-follow-demo-luna'),
    );
    expect(followButton, findsOneWidget);
    await tester.tap(followButton);
    await tester.pumpAndSettle();
    expect(find.text('Siguiendo'), findsOneWidget);

    await tester.tap(find.text('Luna Rivas'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicProfileScreen), findsOneWidget);
  });

  testWidgets('Home Ver todos opens Discover People', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen())));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home-section-action-Fans para descubrir')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverPeopleScreen), findsOneWidget);
  });
}
