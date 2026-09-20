import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/data/discover_data.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/drops_screen.dart';
import 'package:hallyuhub/src/screens/kpop_entity_profile_screen.dart';
import 'package:hallyuhub/src/screens/search_screen.dart';
import 'package:hallyuhub/src/services/local_artist_tag_service.dart';
import 'package:hallyuhub/src/services/local_chat_service.dart';
import 'package:hallyuhub/src/services/local_content_category_service.dart';
import 'package:hallyuhub/src/services/local_drop_service.dart';
import 'package:hallyuhub/src/services/local_fancam_service.dart';
import 'package:hallyuhub/src/services/local_follow_service.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';
import 'package:hallyuhub/src/services/local_story_service.dart';
import 'package:hallyuhub/src/services/local_user_tag_service.dart';
import 'package:hallyuhub/src/utils/kpop_entity_reference.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bangChan = KpopEntity(
  id: 'bang-chan',
  type: KpopEntityType.idol,
  name: 'Bang Chan',
  aliases: ['Christopher Bang', 'Stray Kids'],
);

const _aespa = KpopEntity(
  id: 'aespa',
  type: KpopEntityType.group,
  name: 'aespa',
);

const _leeKnow = KpopEntity(
  id: 'lee-know-real',
  type: KpopEntityType.idol,
  name: 'Lee Know',
  aliases: ['Lee Min-ho', 'Minho', 'Stray Kids'],
);

class _EntityCatalogService extends LocalArtistTagService {
  const _EntityCatalogService();

  @override
  Future<List<KpopEntity>> searchEntities({
    String query = '',
    int limit = 20,
  }) async {
    final normalized = query.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    return const [_bangChan, _leeKnow, _aespa]
        .where((entity) {
          final values = <String>[entity.id, entity.name, ...entity.aliases];
          return values.any(
            (value) =>
                value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '') ==
                normalized,
          );
        })
        .take(limit)
        .toList(growable: false);
  }
}

class _EmptyEntityCatalogService extends LocalArtistTagService {
  const _EmptyEntityCatalogService();

  @override
  Future<List<KpopEntity>> searchEntities({
    String query = '',
    int limit = 20,
  }) async => const [];
}

class _TaggedDropService extends LocalDropService {
  const _TaggedDropService();

  @override
  bool get usesRealDrops => true;

  @override
  Future<List<DropClip>> restoreDrops({
    int limit = 80,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    DropFeedMode feedMode = DropFeedMode.forYou,
  }) async => const [
    DropClip(
      id: 'drop-bang-chan',
      title: 'Ensayo de Bang Chan',
      artist: 'Bang Chan',
      artistId: 'bang-chan',
      creator: '@stay9',
      creatorId: 'stay9',
      creatorName: 'Yessi',
      creatorAvatarAsset: 'assets/demo-users/user-01.jpg',
      audio: 'Audio original',
      imageAsset: 'assets/demo-posts/post-08.jpg',
      views: '4',
      likes: '2',
      comments: '0',
      taggedEntities: [_bangChan],
    ),
  ];

  @override
  Future<Set<String>> restoreLikedDropIds() async => <String>{};

  @override
  Future<Set<String>> restoreSavedDropIds() async => <String>{};
}

class _LegacyLeeKnowDropService extends LocalDropService {
  const _LegacyLeeKnowDropService();

  @override
  bool get usesRealDrops => true;

  @override
  Future<List<DropClip>> restoreDrops({
    int limit = 80,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    DropFeedMode feedMode = DropFeedMode.forYou,
  }) async => const [
    DropClip(
      id: 'drop-lee-know-legacy',
      title: 'Lee Know en el escenario',
      artist: 'Lee Know',
      artistId: 'lee-know',
      creator: '@stay9',
      creatorId: 'stay9',
      creatorName: 'Yessi',
      creatorAvatarAsset: 'assets/demo-users/user-01.jpg',
      audio: 'Audio original',
      imageAsset: 'assets/demo-posts/post-08.jpg',
      views: '4',
      likes: '2',
      comments: '0',
    ),
  ];

  @override
  Future<Set<String>> restoreLikedDropIds() async => <String>{};

  @override
  Future<Set<String>> restoreSavedDropIds() async => <String>{};
}

class _MixedStrayKidsDropService extends LocalDropService {
  const _MixedStrayKidsDropService();

  @override
  bool get usesRealDrops => true;

  @override
  Future<List<DropClip>> restoreDrops({
    int limit = 80,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    DropFeedMode feedMode = DropFeedMode.forYou,
  }) async => const [
    DropClip(
      id: 'drop-lee-know-only',
      title: 'Solo Lee Know',
      artist: 'Lee Know',
      artistId: 'lee-know-real',
      groupId: 'stray-kids',
      creator: '@stay9',
      creatorId: 'stay9',
      creatorName: 'Yessi',
      audio: 'Audio original',
      imageAsset: 'assets/demo-posts/post-08.jpg',
      views: '4',
      likes: '2',
      comments: '0',
      taggedEntities: [_leeKnow],
    ),
    DropClip(
      id: 'drop-bang-chan-only',
      title: 'Solo Bang Chan',
      artist: 'Bang Chan',
      artistId: 'bang-chan',
      groupId: 'stray-kids',
      creator: '@stay9',
      creatorId: 'stay9',
      creatorName: 'Yessi',
      audio: 'Audio original',
      imageAsset: 'assets/demo-posts/post-08.jpg',
      views: '4',
      likes: '2',
      comments: '0',
      taggedEntities: [_bangChan],
    ),
  ];

  @override
  Future<Set<String>> restoreLikedDropIds() async => <String>{};

  @override
  Future<Set<String>> restoreSavedDropIds() async => <String>{};
}

class _NewsTopicEditorHarness extends StatefulWidget {
  const _NewsTopicEditorHarness({required this.onSaved});

  final ValueChanged<Set<String>> onSaved;

  @override
  State<_NewsTopicEditorHarness> createState() =>
      _NewsTopicEditorHarnessState();
}

class _NewsTopicEditorHarnessState extends State<_NewsTopicEditorHarness> {
  Future<void> _open() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewsTopicEditorSheet(
        entities: const [_bangChan, _aespa],
        initialSelection: const {'bang-chan'},
        onSave: (selection) async => widget.onSaved(selection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(onPressed: _open, child: const Text('Editar')),
      ),
    );
  }
}

void main() {
  test(
    'cada grupo e integrante del catálogo tiene una ficha navegable',
    () async {
      const emptyRemote = _EmptyEntityCatalogService();
      for (final group in discoverGroups) {
        final groupEntity = await resolveKpopEntityReference(
          artistTagService: emptyRemote,
          id: group.id,
          name: group.name,
          aliases: group.aliases,
        );
        expect(groupEntity, isNotNull, reason: 'Falta el grupo ${group.name}');
        expect(groupEntity!.type, KpopEntityType.group);

        for (final idol in group.idols) {
          final idolEntity = await resolveKpopEntityReference(
            artistTagService: emptyRemote,
            id: idol.id,
            name: idol.name,
            aliases: <String>[idol.realName, idol.fullName, ...idol.aliases],
          );
          expect(
            idolEntity,
            isNotNull,
            reason: 'Falta ${idol.name} de ${group.name}',
          );
          expect(idolEntity!.type, KpopEntityType.idol);
          expect(idolEntity.name, idol.name);
          expect(idolEntity.bio.trim(), isNotEmpty);
          expect(
            idolEntity.imageAsset.startsWith('assets/demo-'),
            isFalse,
            reason: 'La ficha pública no debe usar un avatar demo',
          );
        }
      }
    },
  );

  test(
    'el nombre exacto de un grupo gana sobre aliases de sus integrantes',
    () async {
      final entity = await resolveKpopEntityReference(
        artistTagService: const _EmptyEntityCatalogService(),
        name: 'Stray Kids',
      );

      expect(entity, isNotNull);
      expect(entity!.type, KpopEntityType.group);
      expect(entity.name, 'Stray Kids');
    },
  );

  test(
    'dos integrantes no comparten identidad aunque tengan el mismo grupo',
    () {
      expect(kpopEntitiesShareIdentity(_leeKnow, _bangChan), isFalse);
      expect(kpopEntitiesShareIdentity(_leeKnow, _leeKnow), isTrue);
    },
  );

  testWidgets('el chip principal de un Drop abre la entidad real etiquetada', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: DropsScreen(dropService: _TaggedDropService(), isActive: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('drop-primary-entity-tag')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(KpopEntityProfileScreen), findsOneWidget);
    expect(find.text('Bang Chan'), findsWidgets);
  });

  testWidgets(
    'una etiqueta antigua de Lee Know resuelve y abre el perfil real',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: DropsScreen(
            dropService: _LegacyLeeKnowDropService(),
            artistTagService: _EntityCatalogService(),
            isActive: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('drop-primary-entity-tag')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(KpopEntityProfileScreen), findsOneWidget);
      expect(find.text('Lee Know'), findsWidgets);
    },
  );

  testWidgets(
    'el perfil de Lee Know incluye un Drop antiguo enlazado por nombre',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 2200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(
          home: KpopEntityProfileScreen(
            entity: _leeKnow,
            currentUser: null,
            artistTagService: _EntityCatalogService(),
            postService: LocalPostService(),
            storyService: LocalStoryService(),
            dropService: _LegacyLeeKnowDropService(),
            fancamService: LocalFancamService(),
            followService: LocalFollowService(),
            chatService: LocalChatService(),
            contentCategoryService: LocalContentCategoryService(),
            userTagService: LocalUserTagService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropsTab = find.textContaining('Drops').first;
      await tester.ensureVisible(dropsTab);
      await tester.tap(dropsTab);
      await tester.pump();

      expect(find.text('Lee Know en el escenario'), findsOneWidget);
    },
  );

  testWidgets(
    'el perfil del idol muestra un Drop enlazado por su entidad resuelta',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 2200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(
          home: KpopEntityProfileScreen(
            entity: _bangChan,
            currentUser: null,
            artistTagService: LocalArtistTagService(),
            postService: LocalPostService(),
            storyService: LocalStoryService(),
            dropService: _TaggedDropService(),
            fancamService: LocalFancamService(),
            followService: LocalFollowService(),
            chatService: LocalChatService(),
            contentCategoryService: LocalContentCategoryService(),
            userTagService: LocalUserTagService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropsTab = find.textContaining('Drops').first;
      await tester.ensureVisible(dropsTab);
      await tester.pump();
      await tester.tap(dropsTab);
      await tester.pump();

      expect(find.text('Ensayo de Bang Chan'), findsOneWidget);
    },
  );

  testWidgets(
    'cada integrante muestra solamente los Drops donde fue etiquetado',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 2200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      Future<void> openProfile(KpopEntity entity) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KpopEntityProfileScreen(
              key: ValueKey(entity.id),
              entity: entity,
              currentUser: null,
              artistTagService: const LocalArtistTagService(),
              postService: const LocalPostService(),
              storyService: const LocalStoryService(),
              dropService: const _MixedStrayKidsDropService(),
              fancamService: const LocalFancamService(),
              followService: const LocalFollowService(),
              chatService: const LocalChatService(),
              contentCategoryService: const LocalContentCategoryService(),
              userTagService: const LocalUserTagService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dropsTab = find.textContaining('Drops').first;
        await tester.ensureVisible(dropsTab);
        await tester.tap(dropsTab);
        await tester.pump();
      }

      await openProfile(_leeKnow);
      expect(find.text('Solo Lee Know'), findsOneWidget);
      expect(find.text('Solo Bang Chan'), findsNothing);

      await openProfile(_bangChan);
      expect(find.text('Solo Bang Chan'), findsOneWidget);
      expect(find.text('Solo Lee Know'), findsNothing);
    },
  );

  testWidgets(
    'el editor de Noticias cancela localmente y guarda al confirmar',
    (tester) async {
      Set<String>? saved;
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: _NewsTopicEditorHarness(
            onSaved: (selection) => saved = Set<String>.from(selection),
          ),
        ),
      );

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('news-topic-editor-option-aespa')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('news-topic-editor-cancel')));
      await tester.pumpAndSettle();
      expect(saved, isNull);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('news-topic-editor-search')),
        'aespa',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('news-topic-editor-option-aespa')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('news-topic-editor-option-bang-chan')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('news-topic-editor-option-aespa')),
      );
      await tester.tap(find.byKey(const ValueKey('news-topic-editor-save')));
      await tester.pumpAndSettle();

      expect(saved, {'bang-chan', 'aespa'});
    },
  );
}
