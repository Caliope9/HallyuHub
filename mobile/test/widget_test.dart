import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/data/demo_data.dart';
import 'package:hallyuhub/src/data/discover_data.dart';
import 'package:hallyuhub/src/hallyu_hub_app.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/services/auth_service.dart';
import 'package:hallyuhub/src/services/backend_config.dart';
import 'package:hallyuhub/src/services/local_chat_service.dart';
import 'package:hallyuhub/src/services/local_follow_service.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';
import 'package:hallyuhub/src/services/local_story_service.dart';
import 'package:hallyuhub/src/services/media_permission_service.dart';
import 'package:hallyuhub/src/services/news_service.dart';
import 'package:hallyuhub/src/services/story_time.dart';
import 'package:hallyuhub/src/screens/discover_detail_screens.dart';
import 'package:hallyuhub/src/screens/post_editor_screen.dart';
import 'package:hallyuhub/src/screens/story_editor_screen.dart';
import 'package:hallyuhub/src/widgets/story_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testEmail = 'qa@hallyuhub.local';
const _testPassword = 'qa-password-2026';

Future<void> seedSignedInLocalUser() async {
  const authService = LocalAuthService();
  final user = await authService.register(
    name: 'Mika',
    username: 'mika',
    email: _testEmail,
    password: _testPassword,
    birthDate: DateTime(1995, 1, 1),
  );
  await authService.saveUser(
    user.copyWith(
      fandom: 'ARMY Chile',
      favoriteGroup: 'BTS',
      bias: 'Jungkook',
      contentRegion: 'Latam',
    ),
  );
}

Future<void> signIn(WidgetTester tester) async {
  await seedSignedInLocalUser();
  await tester.pumpWidget(const HallyuHubApp());
  await tester.pumpAndSettle();
  await acceptLegalIfPresent(tester);
}

Future<void> acceptLegalIfPresent(WidgetTester tester) async {
  if (find.text('Antes de continuar').evaluate().isEmpty) return;
  for (final id in ['terms', 'privacy', 'community', 'beta_notice']) {
    final checkbox = find.byKey(ValueKey('legal-checkbox-$id'));
    await tester.ensureVisible(checkbox);
    await tester.pump();
    await tester.tap(checkbox, warnIfMissed: false);
    await tester.pump();
  }
  final acceptButton = find.text('Aceptar y continuar');
  await tester.ensureVisible(acceptButton);
  await tester.pump();
  await tester.tap(acceptButton, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> closeHallyPopupIfVisible(
  WidgetTester tester,
  String featureId,
) async {
  await tester.pump();
  final closeButton = find.byKey(ValueKey('hally-tip-close-$featureId'));
  if (closeButton.evaluate().isEmpty) return;
  await tester.tap(closeButton);
  await tester.pumpAndSettle();
}

Future<void> followCamilaStories(WidgetTester tester) async {
  await const LocalFollowService().toggleFollowing('demo-cami');
  await tester.pumpAndSettle();
}

Future<void> followValentinaStories(WidgetTester tester) async {
  await const LocalFollowService().toggleFollowing('demo-vale');
  await tester.pumpAndSettle();
}

Future<void> scrollUntilVisibleIn(
  WidgetTester tester,
  Finder scrollable,
  Finder target, {
  Offset scrollDelta = const Offset(0, -520),
}) async {
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, scrollDelta, warnIfMissed: false);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // setMockInitialValues resets the platform mock, but the legacy plugin
    // singleton may already be cached from the previous test. Clear that
    // effective instance as well so every test starts without a session or
    // local user data.
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('backend config keeps demo fallback without Supabase credentials', () {
    const config = BackendConfig(supabaseUrl: '', supabaseAnonKey: '');
    expect(config.hasSupabaseCredentials, isFalse);
    expect(config.mode, HallyuBackendMode.localDemo);
  });

  test('release startup never selects local demo without Supabase', () {
    const missingConfig = BackendConfig(supabaseUrl: '', supabaseAnonKey: '');
    expect(
      resolveBackendStartupMode(
        missingConfig,
        isReleaseBuild: true,
        isPublicAccessRoute: true,
      ),
      BackendStartupMode.publicAccessUnavailable,
    );
    expect(
      resolveBackendStartupMode(
        missingConfig,
        isReleaseBuild: true,
        isPublicAccessRoute: false,
      ),
      BackendStartupMode.configurationError,
    );
    expect(
      resolveBackendStartupMode(
        missingConfig,
        isReleaseBuild: false,
        isPublicAccessRoute: false,
      ),
      BackendStartupMode.localDevelopment,
    );
  });

  testWidgets('starts with a professional auth gate', (tester) async {
    await tester.pumpWidget(const HallyuHubApp());

    expect(find.text('HallyuHub'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu email'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('legal links open modals without changing the form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HallyuHubApp());
    await tester.tap(find.text('Crear cuenta').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-name')),
      'Nombre preservado',
    );

    final legalLinks = <String, String>{
      'Términos de uso': 'Términos y condiciones',
      'Política de privacidad': 'Política de privacidad',
      'Normas de comunidad': 'Normas de comunidad',
    };
    final checkboxKeys = [
      'auth-terms-checkbox',
      'auth-privacy-checkbox',
      'auth-community-checkbox',
    ];

    for (final entry in legalLinks.entries) {
      final checkbox = find.byKey(
        ValueKey(checkboxKeys[legalLinks.keys.toList().indexOf(entry.key)]),
      );
      await tester.ensureVisible(find.text(entry.key));
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets);
      expect(find.text('Cerrar'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      expect(find.text('Nombre preservado'), findsOneWidget);
    }
  });

  testWidgets('registration keeps the selected birth date visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HallyuHubApp());
    await tester.tap(find.text('Crear cuenta').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('auth-birth-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.tap(find.text('Usar fecha'));
    await tester.pumpAndSettle();

    expect(find.text('10/09/2010'), findsOneWidget);
  });

  test('local accounts persist their session until sign out', () async {
    const authService = LocalAuthService();
    final registered = await authService.register(
      name: 'Ana Hallyu',
      username: 'anahallyu',
      email: 'ana@hallyuhub.app',
      password: 'hallyu2026',
      birthDate: DateTime(1995, 1, 1),
    );

    expect((await authService.restoreSession())?.username, '@anahallyu');
    await authService.saveUser(registered.copyWith(bio: 'Mi perfil real'));
    expect((await authService.restoreSession())?.bio, 'Mi perfil real');

    await authService.signOut();
    expect(await authService.restoreSession(), isNull);
  });

  test('own stories persist locally during their active window', () async {
    const storyService = LocalStoryService();
    await storyService.saveOwnStories([
      Story(
        id: 'created-story-test',
        authorId: 'local-user',
        name: 'Tu historia',
        fandom: 'Ahora',
        avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
        imageAsset: 'assets/demo-stories/story-01.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        title: 'Mi historia',
        music: 'HallyuHub Studio · Neon dream loop',
        musicAsset: 'demo-audio/neon-dream.wav',
        elements: const [
          StoryElement(
            id: 'saved-sticker',
            type: StoryElementType.sticker,
            content: '✨',
            position: Offset(0.7, 0.6),
          ),
        ],
        mediaScale: 1.4,
        mediaOffset: Offset(12, -8),
        mediaRotation: 0.12,
        videoTrimStartSeconds: 4,
        videoTrimEndSeconds: 22,
        videoMuted: true,
        createdAt: DateTime.now(),
        isOwn: true,
      ),
    ]);

    final restored = await storyService.restoreOwnStories();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'created-story-test');
    expect(restored.single.imageBytes, orderedEquals([1, 2, 3]));
    expect(restored.single.elements.single.content, '✨');
    expect(restored.single.musicAsset, 'demo-audio/neon-dream.wav');
    expect(restored.single.mediaScale, 1.4);
    expect(restored.single.videoTrimStartSeconds, 4);
    expect(restored.single.videoTrimEndSeconds, 22);
    expect(restored.single.videoMuted, isTrue);
  });

  test(
    'stories use relative time and private archive can repost memories',
    () async {
      const storyService = LocalStoryService();
      final originalDate = DateTime.now().subtract(const Duration(days: 2));
      final story = Story(
        id: 'archive-story-test',
        authorId: 'local-user',
        name: 'Tu historia',
        fandom: 'Ahora',
        avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
        imageAsset: 'assets/demo-stories/story-02.jpg',
        title: 'Recuerdo de prueba',
        createdAt: originalDate,
        isOwn: true,
      );

      expect(storyRelativeTime(story), 'hace 2 días');
      await storyService.savePublishedStory(story, [story]);
      expect(await storyService.restoreStoryArchive(), hasLength(1));

      final memory = await storyService.repostFromArchive(story);
      expect(memory.memoryLabel, 'Recuerdo de hace 2 días');
      expect(
        (await storyService.restoreOwnStories()).map((story) => story.id),
        contains(memory.id),
      );
    },
  );

  test('recovers the twenty original demo profiles', () {
    expect(demoProfiles, hasLength(20));
    expect(demoProfiles.map((profile) => profile.name), contains('Luna Rivas'));
    expect(demoProfiles.map((profile) => profile.name), contains('Bruno Park'));
    expect(
      demoProfiles.every((profile) => profile.avatarAsset.isNotEmpty),
      isTrue,
    );
  });

  test('discover recovers the original group and idol catalog', () {
    expect(discoverGroups, hasLength(23));
    expect(discoverIdols, hasLength(159));
    expect(discoverGroups.map((group) => group.name), contains('BTS'));
    expect(discoverGroups.map((group) => group.name), contains('Stray Kids'));
    expect(discoverIdols.map((idol) => idol.name), contains('Jung Kook'));
  });

  test('discover profiles include legal media metadata and rich bios', () {
    expect(
      discoverGroups.every(
        (group) =>
            group.fullBio.isNotEmpty &&
            group.recommendedSongs.isNotEmpty &&
            group.featuredEras.isNotEmpty &&
            group.imageLicense.isNotEmpty &&
            group.attribution.isNotEmpty,
      ),
      isTrue,
    );
    expect(
      discoverIdols.every(
        (idol) =>
            idol.fullBio.isNotEmpty &&
            idol.highlights.isNotEmpty &&
            idol.imageLicense.isNotEmpty &&
            idol.attribution.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('discover has a scalable artist catalog beyond demo groups', () {
    expect(discoverFeaturedEntities, hasLength(discoverGroups.length));
    expect(discoverArtistEntities.length, greaterThan(discoverGroups.length));
    expect(
      discoverEmergingEntities.map((entity) => entity.status),
      contains(DiscoverEntityStatus.pendingReview),
    );
    expect(
      discoverEmergingEntities.map((entity) => entity.type),
      contains(DiscoverEntityType.coverCrew),
    );
    expect(
      discoverFutureSupabaseTables,
      containsAll([
        'groups',
        'artists',
        'group_members',
        'artist_aliases',
        'news_items',
        'community_suggestions',
        'fancams',
      ]),
    );
    expect(
      discoverNews.expand((item) => item.detectedEntityTags),
      contains('Palermo Cover Crew'),
    );
  });

  test('discover news keeps legal external-source metadata', () {
    expect(discoverNews, isNotEmpty);
    for (final item in discoverNews) {
      expect(item.originalUrl, startsWith('https://'));
      expect(item.generatedSummary, isNotEmpty);
      expect(item.language, 'es');
      expect(item.tags, isNotEmpty);
      expect(item.lastUpdated, isNotEmpty);
      expect(item.imageLicense, isNotEmpty);
      expect(item.searchableText, contains(item.source));
    }
  });

  test('news admin snapshot separates automatic editorial states', () {
    final now = DateTime.utc(2026, 7, 14, 12);
    final snapshot = NewsAdminSnapshot(
      items: [
        NewsAdminItem(
          id: 'confirmed',
          title: 'Confirmed item',
          sourceName: 'Soompi',
          editorialStatus: 'confirmed',
          publishedAt: now,
          articleUrl: 'https://www.soompi.com/article/confirmed',
          isPublished: true,
          autoPublished: true,
          qualityScore: 100,
          rejectionReason: '',
        ),
        NewsAdminItem(
          id: 'rumor',
          title: 'Rumor item',
          sourceName: 'NME',
          editorialStatus: 'rumor',
          publishedAt: now,
          articleUrl: 'https://www.nme.com/news/rumor',
          isPublished: true,
          autoPublished: true,
          qualityScore: 95,
          rejectionReason: '',
        ),
        NewsAdminItem(
          id: 'developing',
          title: 'Developing item',
          sourceName: 'Billboard',
          editorialStatus: 'developing',
          publishedAt: now,
          articleUrl: 'https://www.billboard.com/music/developing',
          isPublished: true,
          autoPublished: true,
          qualityScore: 90,
          rejectionReason: '',
        ),
        NewsAdminItem(
          id: 'incomplete',
          title: 'Incomplete item',
          sourceName: 'Soompi',
          editorialStatus: 'developing',
          publishedAt: now,
          articleUrl: 'https://www.soompi.com/article/incomplete',
          isPublished: false,
          autoPublished: false,
          qualityScore: 70,
          rejectionReason: 'Datos insuficientes',
        ),
      ],
      runs: const [],
    );

    expect(snapshot.autoPublishedCount, 3);
    expect(snapshot.rumorCount, 1);
    expect(snapshot.developingCount, 1);
    expect(snapshot.unpublishedCount, 1);
  });

  test('news metadata uses real publication date and honest links', () {
    const item = DiscoverNews(
      id: 'news-1',
      artist: 'BTS',
      title: 'BTS anuncia una nueva actividad',
      source: 'Google News RSS',
      sourceDomain: 'soompi.com',
      summary: 'Un anuncio breve con información concreta para fans.',
      time: 'hace 2 min inventados',
      status: 'official',
      imageAsset: '',
      publishedAt: '2026-07-14T10:00:00Z',
      originalUrl: 'https://news.google.com/search?q=BTS',
      tags: ['Oficial', 'BTS', 'bts', 'Comeback'],
    );

    expect(
      item.publishedLabelAt(DateTime.parse('2026-07-14T12:00:00Z')),
      'hace 2 h',
    );
    expect(item.displaySource, 'soompi.com');
    expect(item.hasDirectArticleLink, isFalse);
    expect(item.hasRelatedResultsLink, isTrue);
    expect(item.editorialBadge, 'Oficial');
    expect(item.displayTags, ['BTS', 'Comeback']);
  });

  testWidgets('news detail hides technical metadata and labels direct source', (
    tester,
  ) async {
    const item = DiscoverNews(
      id: 'news-2',
      artist: 'BLACKPINK',
      title: 'BLACKPINK comparte novedades de su agenda',
      source: 'Soompi',
      sourceName: 'Soompi',
      summary: 'La agenda suma una nueva fecha anunciada por el grupo.',
      time: '',
      status: 'confirmed',
      imageAsset: '',
      publishedAt: '2026-07-14T10:00:00Z',
      articleUrl: 'https://www.soompi.com/article/example',
      tags: ['BLACKPINK', 'Agenda'],
    );

    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(390, 844), Size(1200, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: NewsDetailScreen(item: item)),
        ),
      );
      await tester.pump();

      expect(find.text('Leer en Soompi'), findsOneWidget);
      expect(find.text('Estado de resumen'), findsNothing);
      expect(find.text('URL original'), findsNothing);
      expect(find.text('Leer noticia completa'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  test('story views and stars persist locally', () async {
    const storyService = LocalStoryService();
    await storyService.saveViewedStoryIds({'story-camila'});
    await storyService.saveStarredStoryIds({'story-agus'});

    expect(await storyService.restoreViewedStoryIds(), {'story-camila'});
    expect(await storyService.restoreStarredStoryIds(), {'story-agus'});
  });

  test('story replies persist as private conversations with context', () async {
    const chatService = LocalChatService();
    final story = stories.first;
    await chatService.sendStoryReply(
      story: story,
      recipient: demoProfileById(story.authorId),
      body: 'Me encantó este comeback',
    );

    var conversations = await chatService.restoreConversations();
    expect(conversations, hasLength(1));
    expect(conversations.single.profileId, 'demo-cami');
    expect(
      conversations.single.messages.single.body,
      'Me encantó este comeback',
    );
    expect(conversations.single.messages.single.storyId, story.id);

    const ownStory = Story(
      id: 'own-story-inbox',
      authorId: 'local-user',
      name: 'Tu historia',
      fandom: 'Ahora',
      avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
      imageAsset: 'assets/demo-stories/story-01.jpg',
      title: 'Mi estreno',
      isOwn: true,
    );
    await chatService.addDemoIncomingStoryReply(
      story: ownStory,
      sender: demoProfileById('demo-agus'),
    );
    conversations = await chatService.restoreConversations();
    expect(conversations, hasLength(2));
    expect(
      conversations
          .firstWhere((conversation) => conversation.profileId == 'demo-agus')
          .unreadCount,
      1,
    );
  });

  testWidgets('story photo starts full canvas and can be dragged to delete', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: StoryEditorScreen(
          initialDraft: StoryDraft(
            type: StoryContentType.image,
            imageAsset: 'assets/demo-stories/story-01.jpg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final canvas = find.byKey(const ValueKey('story-editor-canvas'));
    final media = find.byKey(const ValueKey('story-editor-media'));
    expect(tester.getSize(media), tester.getSize(canvas));

    final canvasRect = tester.getRect(canvas);
    final gesture = await tester.startGesture(tester.getCenter(media));
    await gesture.moveTo(Offset(canvasRect.center.dx, canvasRect.bottom - 34));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('story-editor-delete-zone')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(media, findsNothing);
    expect(
      find.byKey(const ValueKey('story-editor-empty-photo')),
      findsOneWidget,
    );
  });

  testWidgets(
    'story editor exposes desktop resize controls for selected media',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryEditorScreen(
            initialDraft: StoryDraft(
              type: StoryContentType.image,
              imageAsset: 'assets/demo-stories/story-01.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('story-editor-media')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('story-editor-selection-controls')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('story-editor-scale-down')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('story-editor-scale-up')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('story-editor-scale-up')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('story-editor-selection-delete')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('story-editor-empty-photo')),
        findsOneWidget,
      );
    },
  );

  testWidgets('story editor supports image layers and visual filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryEditorScreen(
          initialDraft: StoryDraft(
            type: StoryContentType.image,
            imageAsset: 'assets/demo-stories/story-01.jpg',
            elements: const [
              StoryElement(
                id: 'extra-photo',
                type: StoryElementType.image,
                content: 'assets/demo-posts/post-02.jpg',
                position: Offset(0.58, 0.52),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('story-editor-tool-add-photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-editor-tool-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-element-image-extra-photo')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('story-element-extra-photo')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('story-editor-selection-controls')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-editor-bring-forward')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-editor-send-back')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('story-editor-tool-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-filter-hallyuGlow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byType(StoryFilterOverlay), findsOneWidget);
  });

  test('story service persists layered photos and visual filters', () async {
    SharedPreferences.setMockInitialValues({});
    const storyService = LocalStoryService();
    final story = Story(
      id: 'layered-story',
      authorId: 'local-user',
      name: 'Tu historia',
      fandom: 'Ahora',
      avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
      imageAsset: 'assets/demo-stories/story-01.jpg',
      elements: const [
        StoryElement(
          id: 'photo-layer',
          type: StoryElementType.image,
          content: 'assets/demo-posts/post-03.jpg',
          position: Offset(0.62, 0.58),
          scale: 1.2,
        ),
      ],
      visualFilter: StoryVisualFilter.hallyuGlow,
      createdAt: DateTime.now(),
      isOwn: true,
    );

    await storyService.savePublishedStory(story, [story]);
    final restored = await storyService.restoreOwnStories();

    expect(restored, hasLength(1));
    expect(restored.single.visualFilter, StoryVisualFilter.hallyuGlow);
    expect(restored.single.elements.single.type, StoryElementType.image);
    expect(restored.single.elements.single.scale, 1.2);
  });

  testWidgets('story video editor exposes trim and mute controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: StoryEditorScreen(
          initialDraft: StoryDraft(
            type: StoryContentType.video,
            videoTrimStartSeconds: 0,
            videoTrimEndSeconds: 60,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('story-editor-video-trim')),
      findsOneWidget,
    );
    expect(find.text('Preparando recorte de video...'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('story-editor-video-mute')));
    await tester.pump();
    expect(find.byTooltip('Activar sonido del video'), findsOneWidget);
  });

  testWidgets('does not ask for media permissions automatically at startup', (
    tester,
  ) async {
    await seedSignedInLocalUser();
    await tester.pumpWidget(const HallyuHubApp());
    await tester.pumpAndSettle();
    await acceptLegalIfPresent(tester);

    expect(find.text('Prepará tu experiencia'), findsNothing);
    expect(find.byKey(const ValueKey('media-permission-camera')), findsNothing);
    expect(
      find.byKey(const ValueKey('media-permission-microphone')),
      findsNothing,
    );
  });

  testWidgets('login asks for the email Supabase actually accepts', (
    tester,
  ) async {
    await tester.pumpWidget(const HallyuHubApp());
    await tester.pumpAndSettle();

    expect(find.text('Email o usuario'), findsNothing);
    expect(find.text('Ingresa tu email o usuario'), findsNothing);
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
  });

  testWidgets('recovery gives honest support instructions', (tester) async {
    await tester.pumpWidget(const HallyuHubApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recuperar acceso'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recovery-email')), findsNothing);
    expect(
      find.textContaining('La recuperación automática aún no está disponible'),
      findsOneWidget,
    );
    expect(find.textContaining('soporte@hallyuhub.net'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar acceso'), findsOneWidget);
  });

  test('gallery selection does not require broad media permissions', () async {
    const permissions = MediaPermissionService();
    expect(await permissions.galleryStatus(), MediaAccessResult.ready);
    expect(await permissions.requestGalleryAccess(), MediaAccessResult.ready);
  });

  testWidgets('post editor scales selected stickers and suggests mentions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PostEditorScreen()));
    await tester.pumpAndSettle();
    await closeHallyPopupIfVisible(tester, 'create_post_intro');

    await tester.tap(find.byKey(const ValueKey('post-editor-demo-photo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-editor-caption')),
      'Con @lu',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mention-demo-luna')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('mention-demo-luna')));
    await tester.tap(find.byKey(const ValueKey('mention-demo-luna')));
    await tester.pumpAndSettle();
    expect(find.textContaining('@luna.hallyu'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('post-editor-sticker')),
    );
    await tester.tap(find.byKey(const ValueKey('post-editor-sticker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('✨'));
    await tester.tap(find.text('✨'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post-editor-scale-up')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('post-editor-selection-delete')),
      findsOneWidget,
    );

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('post-editor-scroll')),
      find.byKey(const ValueKey('post-editor-open-tags')),
      scrollDelta: const Offset(0, -320),
    );
    await tester.tap(find.byKey(const ValueKey('post-editor-open-tags')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-panel-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('tag-kind-place')), findsOneWidget);
  });

  testWidgets('story editor suggests mentions and exposes tagging panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: StoryEditorScreen(
          initialDraft: StoryDraft(
            type: StoryContentType.image,
            imageAsset: 'assets/demo-stories/story-01.jpg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('story-editor-tool-text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('story-editor-text-input')),
      'Con @lu',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mention-demo-luna')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mention-demo-luna')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-editor-add-text')));
    await tester.pumpAndSettle();

    expect(find.textContaining('@luna.hallyu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('story-editor-selection-controls')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('story-editor-tool-tagging')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-panel-search')), findsOneWidget);
  });

  testWidgets('renders HallyuHub shell and navigates tabs', (tester) async {
    await signIn(tester);

    expect(find.text('HallyuHub'), findsOneWidget);
    expect(find.text('Historias'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-quick-viral')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-quick-outfit')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-quick-events')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-quick-idols')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-auto-reminder')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    expect(find.text('Feed vivo'), findsNothing);
    expect(find.text('Personas para descubrir'), findsNothing);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Descubre fandoms'), findsOneWidget);
    expect(find.text('Tu mapa del K-pop'), findsNothing);
    expect(
      find.byKey(const ValueKey('discover-activity-strip')),
      findsOneWidget,
    );
    expect(find.text('eventos activos'), findsOneWidget);
  });

  testWidgets('stories open a viewer and expose creation sources', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);
    await followCamilaStories(tester);

    await tester.tap(find.byKey(const ValueKey('story-story-camila')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('story-reply-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-star')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-share')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('story-star')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('story-reply-input')),
      'Qué buena historia',
    );
    await tester.tap(find.byTooltip('Enviar respuesta'));
    await tester.pump();
    expect(find.text('Respuesta enviada a Camila'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar historia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-create-story')));
    await tester.pumpAndSettle();

    expect(find.text('Crear historia'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-create-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-create-gallery')), findsOneWidget);
  });

  testWidgets('story profile and private reply are reachable from viewer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);
    await followCamilaStories(tester);

    await tester.tap(find.byKey(const ValueKey('story-story-camila')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('story-open-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('public-profile-full')), findsOneWidget);
    expect(find.text('Camila Seo'), findsWidgets);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(
      find.byKey(const ValueKey('story-reply-input')),
      'Te quedó increíble',
    );
    await tester.tap(find.byTooltip('Enviar respuesta'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Respuesta enviada a Camila'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar historia'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('header-messages-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dm-inbox')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dm-conversation-demo-cami')),
      findsOneWidget,
    );
    await closeHallyPopupIfVisible(tester, 'messages_intro');
    await tester.tap(find.byKey(const ValueKey('dm-conversation-demo-cami')));
    await tester.pumpAndSettle();
    expect(find.text('Te quedó increíble'), findsOneWidget);
    expect(find.textContaining('Respondiste a su historia'), findsOneWidget);
  });

  testWidgets('story viewer pauses and navigates with mobile gestures', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);
    await followCamilaStories(tester);

    await tester.tap(find.byKey(const ValueKey('story-story-camila')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final progress = find.byKey(const ValueKey('story-progress-active'));
    final navigation = find.byKey(const ValueKey('story-navigation-area'));
    final widthBeforeHold = tester.getSize(progress).width;
    final gesture = await tester.startGesture(tester.getCenter(navigation));
    await tester.pump(const Duration(milliseconds: 900));
    final widthDuringHold = tester.getSize(progress).width;
    expect(widthDuringHold, closeTo(widthBeforeHold, 1));
    expect(find.byKey(const ValueKey('story-paused')), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('story-paused')), findsNothing);

    await tester.fling(navigation, const Offset(-260, 0), 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('Encore favorito'), findsOneWidget);

    await tester.fling(navigation, const Offset(0, 300), 900);
    await tester.pumpAndSettle();
    expect(find.text('Historias'), findsOneWidget);
    final rail = find.byKey(const ValueKey('home-stories-carousel'));
    final viewedRing = find.byKey(
      const ValueKey('story-ring-demo-cami-viewed'),
    );
    for (
      var attempt = 0;
      attempt < 4 && viewedRing.evaluate().isEmpty;
      attempt++
    ) {
      await tester.fling(rail, const Offset(-320, 0), 900);
      await tester.pumpAndSettle();
    }
    expect(viewedRing, findsOneWidget);
  });

  testWidgets('story viewer taps right and left across the sequence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);
    await followCamilaStories(tester);

    await tester.tap(find.byKey(const ValueKey('story-story-camila')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Comeback night'), findsOneWidget);

    final navigation = find.byKey(const ValueKey('story-navigation-area'));
    final rect = tester.getRect(navigation);
    await tester.tapAt(Offset(rect.right - 24, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('Encore favorito'), findsOneWidget);

    await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('Comeback night'), findsOneWidget);

    await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('Comeback night'), findsOneWidget);
  });

  testWidgets('story progress advances automatically across story groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);
    await followCamilaStories(tester);
    await followValentinaStories(tester);

    await tester.tap(find.byKey(const ValueKey('story-story-camila')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5200));
    expect(find.text('Encore favorito'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 5200));
    expect(find.text('Photocard hunt'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar historia'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Historias'), findsOneWidget);
  });

  testWidgets('main screens support swipe navigation without stealing rails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);
    await followCamilaStories(tester);

    await tester.fling(
      find.byKey(const ValueKey('home-stories-carousel')),
      const Offset(-260, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-stories-carousel')), findsOneWidget);

    final mainSwipeArea = find.byKey(const ValueKey('main-tab-swipe-area'));
    await tester.drag(
      find.byKey(const ValueKey('home-auto-reminder')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Descubre fandoms'), findsOneWidget);

    await tester.drag(mainSwipeArea, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('Descubre fandoms'), findsOneWidget);

    await tester.drag(mainSwipeArea, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(find.text('Drops en tendencia'), findsOneWidget);

    await tester.drag(mainSwipeArea, const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(find.text('Descubre fandoms'), findsOneWidget);
  });

  testWidgets('publishes a text story and opens own statistics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.byKey(const ValueKey('story-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-create-story')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('story-text-input')),
      'Mi primera historia HallyuHub',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-publish-text')));
    await tester.pumpAndSettle();
    expect(find.text('Editar historia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('story-editor-publish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mi primera historia HallyuHub'), findsWidgets);
    expect(find.byKey(const ValueKey('story-own-summary')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('story-own-stats')));
    await tester.pumpAndSettle();
    expect(find.text('Vistas y reacciones'), findsOneWidget);
    expect(find.text('Camila Seo'), findsOneWidget);
    expect(find.text('Agus Han'), findsOneWidget);
  });

  testWidgets('story editor publishes movable layers and local music', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.byKey(const ValueKey('story-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-create-story')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('story-text-input')),
      'Editor HallyuHub',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-publish-text')));
    await tester.pumpAndSettle();

    final textLayer = find.text('Editor HallyuHub');
    final layerCenter = tester.getCenter(textLayer);
    await tester.drag(textLayer, const Offset(36, 28));
    await tester.pumpAndSettle();
    expect(tester.getCenter(textLayer).dx, greaterThan(layerCenter.dx + 10));

    await tester.tap(find.byKey(const ValueKey('story-editor-tool-sticker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-sticker-✨')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-editor-tool-music')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('story-music-select-neon-dream')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('story-editor-selected-music')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-editor-remove-music')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('story-editor-publish')));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Editor HallyuHub'), findsWidgets);
    expect(find.text('✨'), findsWidgets);
    expect(find.text('HallyuHub Studio · Neon Dream'), findsOneWidget);
  });

  testWidgets('top bar opens messages and keeps notifications inside inbox', (
    tester,
  ) async {
    await signIn(tester);

    expect(find.byTooltip('Sonido'), findsNothing);
    expect(
      find.byKey(const ValueKey('header-messages-button')),
      findsOneWidget,
    );
    expect(find.byTooltip('Notificaciones'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('header-messages-button')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
  });

  test('local publications persist fields prepared for backend sync', () async {
    const service = LocalPostService();
    const author = AuthUser(
      name: 'Mika',
      username: '@mika',
      email: 'mika@hallyuhub.app',
      avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
      fandom: 'ARMY Chile',
    );
    await service.publish(
      author: author,
      draft: const PostDraft(
        mediaItems: [
          PostMediaItem(
            id: 'carousel-1',
            imageAsset: 'assets/demo-posts/post-02.jpg',
          ),
          PostMediaItem(
            id: 'carousel-2',
            imageAsset: 'assets/demo-posts/post-03.jpg',
          ),
        ],
        caption: 'Publicación persistente',
        tags: ['#BTS', '#HallyuHub'],
        location: 'Santiago',
      ),
    );

    final restored = await service.restorePosts();
    final postId = restored.single.id;

    expect(restored, hasLength(1));
    expect(restored.single.caption, 'Publicación persistente');
    expect(restored.single.tags, ['#BTS', '#HallyuHub']);
    expect(restored.single.location, 'Santiago');
    expect(restored.single.hasCarousel, isTrue);
    expect(restored.single.effectiveMediaItems, hasLength(2));
    expect(
      restored.single.effectiveMediaItems.first.imageAsset,
      'assets/demo-posts/post-02.jpg',
    );
    expect(restored.single.elements, isEmpty);

    await service.setPostLiked(postId, true);
    await service.setPostSaved(postId, true);
    expect(await service.restoreLikedPostIds(), contains(postId));
    expect(await service.restoreSavedPostIds(), contains(postId));

    await service.setPostLiked(postId, false);
    await service.setPostSaved(postId, false);
    expect(await service.restoreLikedPostIds(), isNot(contains(postId)));
    expect(await service.restoreSavedPostIds(), isNot(contains(postId)));

    final comment = await service.addComment(
      author: author,
      postId: postId,
      body: 'Comentario persistente',
    );
    expect(await service.restoreComments(postId), hasLength(1));
    expect(
      (await service.restoreComments(postId)).single.body,
      'Comentario persistente',
    );

    await service.deleteComment(postId: postId, commentId: comment.id);
    expect(await service.restoreComments(postId), isEmpty);
  });

  test('text-only posts persist without injecting demo media', () async {
    const service = LocalPostService();
    const author = AuthUser(
      name: 'Mika',
      username: '@mika',
      email: 'mika@hallyuhub.app',
      avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
      fandom: 'ARMY Chile',
    );

    final post = await service.publish(
      author: author,
      draft: const PostDraft(caption: 'Texto sin foto'),
    );

    expect(post.caption, 'Texto sin foto');
    expect(post.imageAsset, isEmpty);
    expect(post.mediaPath, isEmpty);
    expect(post.effectiveMediaItems, isEmpty);

    final restored = await service.restorePosts();
    expect(restored, hasLength(1));
    expect(restored.single.caption, 'Texto sin foto');
    expect(restored.single.imageAsset, isEmpty);
    expect(restored.single.effectiveMediaItems, isEmpty);
  });

  testWidgets('post editor publishes a text-only draft', (tester) async {
    PostDraft? result;
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<PostDraft>(
                    MaterialPageRoute(builder: (_) => const PostEditorScreen()),
                  );
                },
                child: const Text('Abrir editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-editor-caption')),
      'Publicacion solo texto',
    );
    await tester.tap(find.byKey(const ValueKey('post-editor-publish')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.caption, 'Publicacion solo texto');
    expect(result!.mediaItems, isEmpty);
  });

  testWidgets(
    'home plus opens post editor and publishes into feed and profile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await signIn(tester);

      await tester.tap(find.byKey(const ValueKey('story-create')));
      await tester.pumpAndSettle();
      expect(find.text('Crear contenido'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-create-post')));
      await tester.pumpAndSettle();

      expect(find.text('Nueva publicación'), findsOneWidget);
      expect(find.byKey(const ValueKey('post-editor-gallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-editor-camera')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post-editor-demo-photo')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('post-editor-caption')),
        'Mi primer post desde Home',
      );
      await scrollUntilVisibleIn(
        tester,
        find.byKey(const ValueKey('post-editor-scroll')),
        find.byKey(const ValueKey('post-editor-tags')),
        scrollDelta: const Offset(0, -280),
      );
      await tester.enterText(
        find.byKey(const ValueKey('post-editor-tags')),
        'BTS HallyuHub',
      );
      await scrollUntilVisibleIn(
        tester,
        find.byKey(const ValueKey('post-editor-scroll')),
        find.byKey(const ValueKey('post-editor-location')),
        scrollDelta: const Offset(0, -280),
      );
      await tester.enterText(
        find.byKey(const ValueKey('post-editor-location')),
        'Santiago',
      );
      await tester.tap(find.byKey(const ValueKey('post-editor-publish')));
      await tester.pumpAndSettle();

      expect(
        find.text('Publicación agregada a Inicio y a tu perfil'),
        findsOneWidget,
      );
      final publishedCaption = find.textContaining('Mi primer post desde Home');
      await scrollUntilVisibleIn(
        tester,
        find.byKey(const ValueKey('home-feed-scroll')),
        publishedCaption,
      );
      expect(publishedCaption, findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      final profilePost = find.text('Publicación de Mika');
      await scrollUntilVisibleIn(
        tester,
        find.byKey(const ValueKey('profile-scroll')),
        profilePost,
      );
      expect(profilePost, findsOneWidget);
    },
  );

  testWidgets('profile create publication opens the functional editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicación'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva publicación'), findsOneWidget);
    expect(find.byKey(const ValueKey('post-editor-caption')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-editor-gallery')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-editor-camera')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('post-editor-use-location')),
      findsOneWidget,
    );
  });

  testWidgets('bottom navigation exposes fancams and header opens messages', (
    tester,
  ) async {
    await signIn(tester);

    expect(find.text('Fancams'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('header-messages-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('header-messages-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dm-inbox')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('messages-notifications-button')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fancams'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fancams-reels-feed')), findsOneWidget);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-open-fancams')), findsNothing);
  });

  testWidgets('discover opens group idol and related fancams', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Tu mapa del K-pop'), findsNothing);
    expect(find.text('Grupos e idols'), findsOneWidget);
    expect(find.text('Drops'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.byKey(const ValueKey('discover-open-groups')),
    );
    await tester.tap(find.byKey(const ValueKey('discover-open-groups')));
    await tester.pumpAndSettle();
    expect(find.text('Grupos y artistas'), findsOneWidget);
    await closeHallyPopupIfVisible(tester, 'artists_intro');

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.byKey(const ValueKey('discover-group-bts')),
      scrollDelta: const Offset(0, 420),
    );
    await tester.tap(find.byKey(const ValueKey('discover-group-bts')));
    await tester.pumpAndSettle();
    expect(find.text('BTS'), findsWidgets);
    expect(find.text('ARMY · 2013'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byType(Scrollable).last,
      find.byKey(const ValueKey('discover-idol-bts-jung-kook')),
    );
    await tester.tap(find.byKey(const ValueKey('discover-idol-bts-jung-kook')));
    await tester.pumpAndSettle();
    expect(find.text('Jung Kook'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('discover-idol-fancams')));
    await tester.pumpAndSettle();
    expect(find.text('Jung Kook · Fancams'), findsWidgets);
    expect(find.byKey(const ValueKey('fancams-reels-feed')), findsOneWidget);
    expect(find.text('Seven era focus'), findsOneWidget);
  });

  testWidgets('discover search finds events and profiles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search-input')),
      'Palermo',
    );
    await tester.pumpAndSettle();

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.text('Eventos · 1'),
    );
    expect(find.text('Artistas y proyectos · 1'), findsOneWidget);
    expect(find.text('Palermo Cover Crew'), findsOneWidget);
    expect(find.text('Eventos · 1'), findsOneWidget);
    expect(find.text('STAY fanmeeting'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.byKey(const ValueKey('search-input')),
      scrollDelta: const Offset(0, 520),
    );
    await tester.enterText(find.byKey(const ValueKey('search-input')), 'Luna');
    await tester.pumpAndSettle();
    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.text('Usuarios · 1'),
    );
    expect(find.text('Usuarios · 1'), findsOneWidget);
    expect(find.text('Luna Rivas'), findsOneWidget);
  });

  testWidgets('discover can submit a local pending artist suggestion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.byKey(const ValueKey('discover-suggest-entity')),
    );
    await tester.tap(find.byKey(const ValueKey('discover-suggest-entity')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('discover-suggestion-name')),
      'Proyecto Cami',
    );
    await tester.enterText(
      find.byKey(const ValueKey('discover-suggestion-country')),
      'Argentina',
    );
    await tester.enterText(
      find.byKey(const ValueKey('discover-suggestion-region')),
      'Buenos Aires',
    );
    await tester.enterText(
      find.byKey(const ValueKey('discover-suggestion-description')),
      'Crew local de fans para dance covers y proyectos K-pop.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('discover-suggestion-reference')),
      'https://example.com/proyecto-cami',
    );
    await tester.tap(find.byKey(const ValueKey('discover-submit-suggestion')));
    await tester.pumpAndSettle();

    for (
      var attempt = 0;
      attempt < 6 &&
          find.byKey(const ValueKey('search-input')).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(
        find.byKey(const ValueKey('discover-scroll')),
        const Offset(0, 680),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('search-input')),
      'Proyecto Cami',
    );
    await tester.pumpAndSettle();

    expect(find.text('Proyecto Cami'), findsWidgets);
    expect(find.text('Pendiente de revisión'), findsWidgets);
  });

  testWidgets('discover can create a local demo community', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('discover-scroll')),
      find.byKey(const ValueKey('discover-open-communities')),
      scrollDelta: const Offset(0, -240),
    );
    await tester.tap(find.byKey(const ValueKey('discover-open-communities')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discover-create-community')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('discover-create-community')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('community-name')),
      'ARMY Rosario',
    );
    await tester.enterText(
      find.byKey(const ValueKey('community-province')),
      'Santa Fe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('community-city')),
      'Rosario',
    );
    await tester.enterText(
      find.byKey(const ValueKey('community-fandom')),
      'BTS',
    );
    await tester.enterText(
      find.byKey(const ValueKey('community-description')),
      'Meetups, trades y escucha grupal para fans locales.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('community-create-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-create-submit')));
    await tester.pumpAndSettle();

    expect(find.text('ARMY Rosario'), findsOneWidget);
    expect(find.text('ARMY Rosario creada en modo demo'), findsOneWidget);
  });

  testWidgets('feed captions show author metadata and expand long text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, -620),
    );
    await tester.pumpAndSettle();

    final caption = find.byKey(const ValueKey('post-caption-cup-sleeve-live'));
    await tester.ensureVisible(caption);
    await tester.pumpAndSettle();

    expect(find.text('Barrio Italia, Santiago'), findsOneWidget);
    expect(find.text('#Santiago'), findsOneWidget);
    expect(tester.widget<Text>(caption).maxLines, 2);

    await tester.tap(
      find.byKey(const ValueKey('post-caption-toggle-cup-sleeve-live')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver menos'), findsOneWidget);
    expect(tester.widget<Text>(caption).maxLines, isNull);
  });

  testWidgets('feed actions support saving and commenting', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.drag(
      find.byKey(const ValueKey('home-feed-scroll')),
      const Offset(0, -620),
    );
    await tester.pumpAndSettle();

    final saveAction = find.byKey(const ValueKey('save-cup-sleeve-live'));
    await tester.ensureVisible(saveAction);
    await tester.pumpAndSettle();
    await tester.tap(saveAction);
    await tester.pump();
    expect(find.text('Post guardado'), findsOneWidget);

    final commentAction = find.byKey(const ValueKey('comment-cup-sleeve-live'));
    await tester.ensureVisible(commentAction);
    await tester.pumpAndSettle();
    await tester.tap(commentAction);
    await tester.pumpAndSettle();

    expect(find.text('Comentarios'), findsOneWidget);
    expect(find.text('Vale ARMY'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tami')).dy <
          tester.getTopLeft(find.text('Vale ARMY')).dy,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('comment-star-cup-tami')));
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('comment-reply-cup-tami')));
    await tester.pumpAndSettle();
    expect(find.text('Respondiendo a @tamiphotos'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('comment-input-cup-sleeve-live')),
      'Gracias por compartir',
    );
    await tester.tap(find.byTooltip('Enviar comentario'));
    await tester.pumpAndSettle();
    expect(find.text('Gracias por compartir'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('comment-input-cup-sleeve-live')),
      'Nos vemos alla',
    );
    await tester.tap(find.byTooltip('Enviar comentario'));
    await tester.pumpAndSettle();

    expect(find.text('Nos vemos alla'), findsOneWidget);
  });

  testWidgets('profile actions open product flows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await closeHallyPopupIfVisible(tester, 'profile_intro');

    expect(find.text('Mika'), findsWidgets);
    expect(find.text('ARMY Chile'), findsWidgets);
    expect(
      find.byKey(const ValueKey('profile-highlight-Fancams')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-posts')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-seguidores')),
        matching: find.text('20'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-siguiendo')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-estrellas')),
        matching: find.text('99.7K'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('profile-stat-seguidores')));
    await tester.pumpAndSettle();
    expect(find.text('Seguidores de Mika'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('connections-search')),
      'cs',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connection-demo-cami')), findsOneWidget);
    expect(find.byKey(const ValueKey('connection-demo-luna')), findsNothing);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-create')));
    await tester.pumpAndSettle();
    expect(find.text('Crear en HallyuHub'), findsOneWidget);
    await tester.tap(find.text('Historia'));
    await tester.pumpAndSettle();
    expect(find.text('Crear historia'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-create-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-create-gallery')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('story-create-camera')));
    await tester.pumpAndSettle();
    expect(find.text('Preparar cámara'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar cámara'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-share')));
    await tester.pumpAndSettle();
    expect(find.text('Compartir perfil'), findsOneWidget);
    expect(find.text('Enviar a seguidores'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Copiar enlace'));
    await tester.pumpAndSettle();
    expect(find.text('Enlace copiado'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('profile-scroll')),
      find.byKey(const ValueKey('profile-activity-save-post-event')),
    );
    await tester.tap(
      find.byKey(const ValueKey('profile-activity-save-post-event')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardado en perfil'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('profile-scroll')),
      find.byKey(const ValueKey('profile-tab-saved')),
      scrollDelta: const Offset(0, 520),
    );
    await closeHallyPopupIfVisible(tester, 'profile_intro');
    await tester.ensureVisible(find.byKey(const ValueKey('profile-tab-saved')));
    await tester.tap(find.byKey(const ValueKey('profile-tab-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Encuentro fandom pastel'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('profile-scroll')),
      find.byKey(const ValueKey('profile-edit')),
      scrollDelta: const Offset(0, 520),
    );
    await closeHallyPopupIfVisible(tester, 'profile_intro');
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('profile-scroll')),
      find.byKey(const ValueKey('profile-activity-star-post-event')),
    );
    await tester.tap(
      find.byKey(const ValueKey('profile-activity-star-post-event')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estrella agregada'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('profile-activity-comment-post-event')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('comment-input-post-event')),
      'Qué lindo encuentro',
    );
    await tester.tap(find.byTooltip('Enviar comentario'));
    await tester.pumpAndSettle();
    expect(find.text('Qué lindo encuentro'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
  });

  testWidgets('profile collection tabs create private trade interest', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Colección'), findsOneWidget);
    expect(find.text('Trades/Ventas'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-create')));
    await tester.pumpAndSettle();
    expect(find.text('Agregar a colección'), findsOneWidget);
    expect(find.text('Publicar trade/venta'), findsOneWidget);
    expect(find.text('Agregar a wishlist'), findsOneWidget);
    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-tab-collection')));
    await tester.pumpAndSettle();
    expect(find.text('Jung Kook Seven photocard'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-tab-trades')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-tab-trades')));
    await tester.pumpAndSettle();
    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('profile-scroll')),
      find.byKey(const ValueKey('collection-item-trade-cami-lisa-bornpink')),
    );
    await tester.tap(
      find.byKey(const ValueKey('collection-item-trade-cami-lisa-bornpink')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lisa Born Pink photocard'), findsWidgets);
    await scrollUntilVisibleIn(
      tester,
      find.byKey(
        const ValueKey('collection-detail-scroll-trade-cami-lisa-bornpink'),
      ),
      find.byKey(
        const ValueKey('collection-interest-trade-cami-lisa-bornpink'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('collection-interest-trade-cami-lisa-bornpink'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chat creado con Camila Seo'), findsOneWidget);

    final conversations = await const LocalChatService().restoreConversations();
    final camiConversation = conversations.firstWhere(
      (conversation) => conversation.profileId == 'demo-cami',
    );
    expect(camiConversation.name, 'Camila Seo');
    expect(camiConversation.latestMessage?.body, contains('Lisa Born Pink'));
  });

  testWidgets('profile opens the private story archive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const storyService = LocalStoryService();
    final archived = Story(
      id: 'profile-archive-story',
      authorId: 'local-user',
      name: 'Tu historia',
      fandom: 'Ahora',
      avatarAsset: 'assets/demo-users/ai-luna-rivas.png',
      imageAsset: 'assets/demo-stories/story-02.jpg',
      title: 'Historia guardada',
      createdAt: DateTime.now(),
      isOwn: true,
    );
    await storyService.savePublishedStory(archived, [archived]);
    await signIn(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    final archiveTab = find.byKey(const ValueKey('profile-tab-archive'));
    await tester.ensureVisible(archiveTab);
    await tester.pumpAndSettle();
    await tester.tap(archiveTab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-open-story-archive')));
    await tester.pumpAndSettle();

    expect(find.text('Archivo privado'), findsWidgets);
    expect(
      find.byKey(const ValueKey('story-archive-profile-archive-story')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-archive-repost-profile-archive-story')),
      findsOneWidget,
    );
  });

  testWidgets('visitor profile exposes searchable community lists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('profile-scroll')),
      find.byKey(const ValueKey('profile-activity-author-post-event')),
    );
    await tester.tap(
      find.byKey(const ValueKey('profile-activity-author-post-event')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('public-profile-demo-cami-stat-seguidores')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seguidores'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('connections-search')),
      'lr',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connection-demo-luna')), findsOneWidget);
  });

  testWidgets('home suggests new profiles and supports following', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('home-feed-scroll')),
      find.byKey(const ValueKey('home-suggestion-follow-demo-luna')),
    );
    await tester.tap(
      find.byKey(const ValueKey('home-suggestion-follow-demo-luna')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ahora sigues a Luna Rivas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-suggestion-follow-demo-luna')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('home-suggestion-open-demo-luna')),
      findsNothing,
    );
  });

  testWidgets('drops support stars and editable comments', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await signIn(tester);

    await tester.tap(find.text('Drops').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('drop-star-Challenge de medianoche')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estrella agregada'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('drop-comment-Challenge de medianoche')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('comment-input-challenge-de-medianoche')),
      'Ensayo listo para el challenge',
    );
    await tester.tap(find.byTooltip('Enviar comentario'));
    await tester.pumpAndSettle();

    expect(find.text('Ensayo listo para el challenge'), findsOneWidget);
  });

  testWidgets('settings can update profile data and sign out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HallyuHubApp());

    await tester.tap(find.text('Crear cuenta').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('auth-name')), 'sol diaz');
    await tester.enterText(
      find.byKey(const ValueKey('auth-username')),
      'soldiaz',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'sol@hallyuhub.app',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'hallyu2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'hallyu2026',
    );
    for (final key in [
      'auth-terms-checkbox',
      'auth-privacy-checkbox',
      'auth-community-checkbox',
    ]) {
      final checkbox = find.byKey(ValueKey(key));
      await tester.ensureVisible(checkbox);
      await tester.pump();
      await tester.tap(checkbox);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('auth-birth-date')));
    await tester.tap(find.byKey(const ValueKey('auth-birth-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.tap(find.text('Usar fecha'));
    await tester.pumpAndSettle();
    expect(find.text('10/09/2010'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    await acceptLegalIfPresent(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Sol Diaz'), findsWidgets);
    expect(find.text('@soldiaz · Ubicación no configurada'), findsOneWidget);
    expect(find.text('Agregar fandom'), findsWidgets);
    for (final label in ['posts', 'seguidores', 'siguiendo', 'estrellas']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('profile-stat-$label')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('profile-settings-open')));
    await tester.pumpAndSettle();

    expect(find.text('Centro de cuenta'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
    expect(find.text('Datos personales'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('settings-home-scroll')),
      find.byKey(const ValueKey('settings-item-editProfile')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-item-editProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('settings-name')),
      'Sol Hallyu',
    );
    await tester.tap(find.byKey(const ValueKey('settings-save')));
    await tester.pump();

    expect(find.text('Cambios guardados'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('settings-home-scroll')),
      find.byKey(const ValueKey('settings-item-privacyPolicy')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-item-privacyPolicy')));
    await tester.pumpAndSettle();
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(
      find.textContaining('HallyuHub puede recolectar y procesar datos'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Sol Hallyu'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('profile-settings-open')));
    await tester.pumpAndSettle();
    await scrollUntilVisibleIn(
      tester,
      find.byKey(const ValueKey('settings-home-scroll')),
      find.byKey(const ValueKey('settings-item-logout')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-item-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión ahora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
