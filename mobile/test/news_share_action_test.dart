import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/data/discover_data.dart';
import 'package:hallyuhub/src/screens/discover_detail_screens.dart';

void main() {
  testWidgets('news detail exposes the real share-to-post action', (
    tester,
  ) async {
    var shared = false;
    const item = DiscoverNews(
      id: 'news-test',
      artist: 'BTS',
      title: 'Nueva noticia K-pop',
      source: 'Fuente K-pop',
      summary: 'Resumen breve de la noticia.',
      time: 'Ahora',
      status: 'confirmed',
      imageAsset: '',
      articleUrl: 'https://example.com/noticia-kpop',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewsDetailScreen(
            item: item,
            onShareToPost: () => shared = true,
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('discover-news-share-to-post'));
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(shared, isTrue);
  });
}
