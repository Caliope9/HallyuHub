import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/outfit_screen.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';

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
    expect(find.byKey(const ValueKey('outfit-card-outfit-post-1')), findsOneWidget);

    await tester.tap(find.text('Más populares'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('Categoría de Outfit-stage')),
    );
    await tester.pumpAndSettle();

    expect(service.calls, contains('popular:all:0'));
    expect(service.calls, contains('popular:stage:0'));
  });
}
