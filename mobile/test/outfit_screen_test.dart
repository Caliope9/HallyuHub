import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/outfit_screen.dart';
import 'package:hallyuhub/src/screens/post_editor_screen.dart';
import 'package:hallyuhub/src/screens/profile_screen.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';
import 'package:hallyuhub/src/widgets/profile_category_chips.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOutfitPostService extends LocalPostService {
  final calls = <String>[];

  final post = const HubPost(
    id: 'outfit-post-1',
    authorId: 'author-1',
    author: 'Minji',
    username: '@minji',
    avatarAsset: '',
    imageAsset: '',
    caption: 'Stage outfit',
    tags: ['#outfit'],
    likes: '12',
    comments: '3',
    mood: 'Outfit',
    time: 'Ahora',
    shares: '1',
    saves: '4',
    artist: 'NewJeans',
  );

  @override
  Future<List<OutfitFeedItem>> restoreOutfitFeed({
    OutfitFeedMode mode = OutfitFeedMode.forYou,
    String category = 'all',
    int limit = 24,
    int offset = 0,
  }) async {
    calls.add('${mode.name}:$category:$offset');
    return [
      OutfitFeedItem(post: post, categoryKey: 'outfit_stage'),
      OutfitFeedItem(post: post, categoryKey: 'outfit_stage'),
    ];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Outfit screen filters modes and deduplicates post ids', (
    tester,
  ) async {
    final service = _FakeOutfitPostService();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: OutfitScreen(postService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Outfits'), findsOneWidget);
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('Más populares'), findsOneWidget);
    expect(find.text('Siguiendo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Categoría de Outfit-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('outfit-card-outfit-post-1')),
      findsOneWidget,
    );

    await tester.tap(find.text('Más populares'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('Categoría de Outfit-stage')));
    await tester.pumpAndSettle();

    expect(service.calls, contains('popular:all:0'));
    expect(service.calls, contains('popular:stage:0'));
  });

  testWidgets('closing outfit editor returns to profile', (tester) async {
    final user = AuthUser(
      name: 'Fan de prueba',
      username: '@fanprueba',
      email: 'fan@example.test',
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

    for (
      var attempt = 0;
      attempt < 3 && find.byType(PremiumProfileHighlights).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(
        find.byKey(const ValueKey('profile-scroll')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
    }
    expect(find.byType(PremiumProfileHighlights), findsOneWidget);
    await tester.drag(
      find.byType(PremiumProfileHighlights),
      const Offset(-650, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-highlight-Outfit')));
    await tester.pumpAndSettle();
    expect(find.byType(OutfitScreen), findsOneWidget);

    await tester.tap(find.text('Crear Outfit'));
    await tester.pumpAndSettle();
    expect(find.byType(PostEditorScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar editor'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(OutfitScreen), findsNothing);
    expect(find.byType(PostEditorScreen), findsNothing);
  });
}
