import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/widgets/hallyu_post_card.dart';
import 'package:hallyuhub/src/widgets/story_canvas.dart';

HubPost _post(String id, List<String> assets) {
  return HubPost(
    id: id,
    authorId: 'author-$id',
    author: 'Fan $id',
    username: '@fan_$id',
    avatarAsset: 'assets/demo-users/user-01.jpg',
    imageAsset: '',
    caption: 'Carrusel de prueba',
    tags: const [],
    likes: '1',
    comments: '0',
    mood: '',
    time: 'Ahora',
    shares: '0',
    saves: '0',
    mediaItems: [
      for (var index = 0; index < assets.length; index++)
        PostMediaItem(id: '$id-media-$index', imageAsset: assets[index]),
    ],
  );
}

Widget _card(HubPost post) {
  return HallyuPostCard(
    post: post,
    liked: false,
    saved: false,
    shared: false,
    likesLabel: post.likes,
    commentsLabel: post.comments,
    sharesLabel: post.shares,
    savesLabel: post.saves,
    onLike: () {},
    onComment: () {},
    onShare: () {},
    onSave: () {},
  );
}

void main() {
  const firstAssets = [
    'assets/demo-posts/post-01.jpg',
    'assets/demo-posts/post-02.jpg',
  ];

  testWidgets('post carousel swipes and keeps complete image fitting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    final post = _post('one', firstAssets);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: SingleChildScrollView(child: _card(post)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
    expect(
      tester.widget<StoryCanvas>(find.byType(StoryCanvas).first).mediaFit,
      BoxFit.contain,
    );

    final carousel = find.byKey(
      const PageStorageKey<String>('post-media-carousel-one'),
    );
    await tester.drag(carousel, const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('mouse drag works and carousels keep independent pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = _post('first', firstAssets);
    final second = _post('second', const [
      'assets/demo-posts/post-03.jpg',
      'assets/demo-posts/post-04.jpg',
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SingleChildScrollView(child: _card(first))),
              Expanded(child: SingleChildScrollView(child: _card(second))),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstCarousel = find.byKey(
      const PageStorageKey<String>('post-media-carousel-first'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(firstCarousel),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    final firstPill = find.descendant(
      of: find.byKey(const ValueKey('post-carousel-pill-first')),
      matching: find.text('2/2'),
    );
    final secondPill = find.descendant(
      of: find.byKey(const ValueKey('post-carousel-pill-second')),
      matching: find.text('1/2'),
    );
    expect(firstPill, findsOneWidget);
    expect(secondPill, findsOneWidget);
  });

  testWidgets('six-photo carousel reaches the last item without overlap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final post = _post('six', const [
      'assets/demo-posts/post-01.jpg',
      'assets/demo-posts/post-02.jpg',
      'assets/demo-posts/post-03.jpg',
      'assets/demo-posts/post-04.jpg',
      'assets/demo-posts/post-05.jpg',
      'assets/demo-posts/post-06.jpg',
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: SingleChildScrollView(child: _card(post)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final carousel = find.byKey(
      const PageStorageKey<String>('post-media-carousel-six'),
    );
    for (var page = 1; page < 6; page++) {
      await tester.drag(carousel, const Offset(-280, 0));
      await tester.pumpAndSettle();
    }

    expect(find.text('6/6'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('post-media-six-six-media-5-5')),
      findsOneWidget,
    );
  });
}
