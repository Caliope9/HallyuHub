import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/widgets/hallyu_post_card.dart';

HubPost _post({required String caption, List<KpopEntity> entities = const []}) {
  return HubPost(
    id: 'shared-news-post',
    author: 'Fan',
    username: '@fan',
    avatarAsset: '',
    imageAsset: '',
    caption: caption,
    tags: const ['#NoticiasKpop'],
    likes: '0',
    comments: '0',
    mood: 'Texto',
    time: 'Ahora',
    shares: '0',
    saves: '0',
    taggedEntities: entities,
  );
}

Widget _feedCard(HubPost post, {ValueChanged<String>? onOpenNews}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HallyuPostCard(
          post: post,
          liked: false,
          saved: false,
          shared: false,
          likesLabel: '0',
          commentsLabel: '0',
          sharesLabel: '0',
          savesLabel: '0',
          onLike: () {},
          onComment: () {},
          onShare: () {},
          onSave: () {},
          onOpenNews: onOpenNews,
        ),
      ),
    ),
  );
}

void main() {
  const articleUrl = 'https://news.example.com/kpop/article-16';
  const storyTitle = 'Stray Kids inicia el festival internacional';
  const sharedNews = SharedNewsPostContent(
    title: storyTitle,
    source: 'KBS World Español',
    summary: 'El grupo encabezará la apertura del festival.',
    articleUrl: articleUrl,
  );

  test("news metadata is separated from and preserves the user's comment", () {
    final caption = sharedNews.attachToComment('Qué ganas de ver esto 💜');
    final parsed = SharedNewsPostContent.fromCaption(caption);

    expect(parsed.comment, 'Qué ganas de ver esto 💜');
    expect(parsed.news?.title, storyTitle);
    expect(parsed.news?.source, 'KBS World Español');
    expect(parsed.news?.articleUrl, articleUrl);
  });

  testWidgets(
    'news without an image has an intentional fallback and attribution',
    (tester) async {
      await tester.pumpWidget(
        _feedCard(_post(caption: sharedNews.attachToComment(''))),
      );

      expect(
        find.byKey(const ValueKey('shared-news-card-shared-news-post')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shared-news-fallback')),
        findsOneWidget,
      );
      expect(find.text('HallyuHub Noticias'), findsOneWidget);
      expect(find.text(storyTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('shared-news-source')), findsOneWidget);
      expect(find.text('Ver noticia'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('post-media-shared-news-post')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'news with an image renders a cover and image failure falls back',
    (tester) async {
      final news = SharedNewsPostContent(
        title: storyTitle,
        source: 'KBS World Español',
        summary: 'Resumen real.',
        articleUrl: articleUrl,
        imageUrl: 'https://images.example.com/stray-kids.jpg',
      );
      await tester.pumpWidget(
        _feedCard(_post(caption: news.attachToComment(''))),
      );

      expect(find.byType(Image), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shared-news-fallback')),
        findsOneWidget,
      );
      expect(find.text(storyTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('shared-news-source')), findsOneWidget);
    },
  );

  testWidgets('cover, title, and Ver noticia open the original article URL', (
    tester,
  ) async {
    final openedUrls = <String>[];
    await tester.pumpWidget(
      _feedCard(
        _post(
          caption: SharedNewsPostContent(
            title: storyTitle,
            source: 'KBS World Español',
            summary: 'Resumen real.',
            articleUrl: articleUrl,
            imageUrl: 'https://images.example.com/stray-kids.jpg',
          ).attachToComment('Comentario de fan'),
        ),
        onOpenNews: openedUrls.add,
      ),
    );

    final cover = find.byKey(const ValueKey('shared-news-cover-open'));
    await tester.ensureVisible(cover);
    await tester.tap(cover);
    final title = find.byKey(const ValueKey('shared-news-title-open'));
    await tester.ensureVisible(title);
    await tester.tap(title);
    final open = find.byKey(const ValueKey('shared-news-open'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    expect(openedUrls, [articleUrl, articleUrl, articleUrl]);
    final captionFinder = find.byKey(
      const ValueKey('post-caption-shared-news-post'),
    );
    final caption = tester.widget<Text>(captionFinder);
    expect(caption.textSpan!.toPlainText(), contains('Comentario de fan'));
  });

  testWidgets('real artist entity tags remain attached and visible', (
    tester,
  ) async {
    const entity = KpopEntity(
      id: 'entity-stray-kids',
      type: KpopEntityType.group,
      name: 'Stray Kids',
    );
    await tester.pumpWidget(
      _feedCard(
        _post(
          caption: sharedNews.attachToComment('Merecido 💜'),
          entities: [entity],
        ),
      ),
    );

    expect(find.text('Stray Kids'), findsOneWidget);
    final captionFinder = find.byKey(
      const ValueKey('post-caption-shared-news-post'),
    );
    final caption = tester.widget<Text>(captionFinder);
    expect(caption.textSpan!.toPlainText(), contains('Merecido 💜'));
  });
}
