import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/data/discover_data.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/public_profile_screen.dart';
import 'package:hallyuhub/src/services/local_follow_service.dart';
import 'package:hallyuhub/src/utils/community_membership_sections.dart';
import 'package:hallyuhub/src/widgets/community_chat_message_tile.dart';
import 'package:hallyuhub/src/widgets/brand_mark.dart';
import 'package:hallyuhub/src/widgets/profile_category_chips.dart';
import 'package:shared_preferences/shared_preferences.dart';

CommunityProfile _profile({
  String id = 'profile-1',
  String name = 'Kimi Park',
  String username = '@kpark',
  String bio = 'Fan de Hallyu',
}) => CommunityProfile(
  id: id,
  name: name,
  username: username,
  city: '',
  country: '',
  fandom: 'Multi fandom',
  favoriteGroup: '',
  bio: bio,
  avatarAsset: '',
  followers: '0',
  posts: '0',
  colors: const [Colors.purple, Colors.cyan],
);

DiscoverCommunity _community(String id, String name) => DiscoverCommunity(
  id: id,
  name: name,
  region: 'Buenos Aires',
  members: '4',
  activity: '',
  fandom: 'Multi fandom',
  description: '',
  posts: const [],
);

class _RelationshipFixture extends LocalFollowService {
  _RelationshipFixture({required this.following});

  bool following;

  @override
  Future<Set<String>> restoreFollowingIds() async =>
      following ? {'profile-1'} : <String>{};

  @override
  Future<FollowCounts> restoreCounts(String profileId) async =>
      const FollowCounts();

  @override
  Future<bool> toggleFollowing(String profileId) async {
    following = !following;
    return following;
  }
}

class _ExactProfileFixture extends _RelationshipFixture {
  _ExactProfileFixture(this.profile) : super(following: false);

  final CommunityProfile profile;
  int exactLookups = 0;
  int searchLookups = 0;

  @override
  bool get usesRealProfiles => true;

  @override
  Future<List<CommunityProfile>> restoreProfilesByIds(List<String> ids) async {
    exactLookups++;
    return ids.contains(profile.id) ? [profile] : [];
  }

  @override
  Future<List<CommunityProfile>> restoreProfiles({
    String query = '',
    int limit = 30,
    bool excludeFollowing = false,
  }) async {
    searchLookups++;
    return [profile];
  }
}

class _DelayedProfileFixture extends _RelationshipFixture {
  _DelayedProfileFixture() : super(following: false);

  final response = Completer<CommunityProfile?>();

  @override
  bool get usesRealProfiles => true;

  @override
  Future<CommunityProfile?> restoreProfileById(String id) => response.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('joined communities are listed first and never duplicated', () {
    final result = splitCommunityMembership(
      communities: [
        _community('not-joined', 'Explore'),
        _community('joined', 'Joined'),
        _community('joined', 'Duplicate'),
      ],
      joinedIds: {'joined'},
    );

    expect(result.joined.map((item) => item.name), ['Joined']);
    expect(result.available.map((item) => item.name), ['Explore']);
  });

  testWidgets('tapping avatar or name opens that exact public profile', (
    tester,
  ) async {
    final profile = _profile();
    final opened = <CommunityProfile>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CommunityChatMessageTile(
                profile: profile,
                body: 'Hola comunidad',
                timeLabel: '10:24',
                isCurrentUser: false,
                onOpenProfile: opened.add,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('community-message-author-profile-1')),
    );
    await tester.pump();
    expect(opened.single.id, 'profile-1');
    expect(opened.single.username, '@kpark');
    expect(opened.single.name, 'Kimi Park');

    await tester.tap(
      find.byKey(const ValueKey('community-message-avatar-profile-1')),
    );
    await tester.pump();
    expect(opened, hasLength(2));
    expect(opened.last, same(profile));
  });

  testWidgets('chat author uses public name and username, never email', (
    tester,
  ) async {
    final profile = _profile(name: 'Kimi Park', username: '@kpark');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityChatMessageTile(
            profile: profile,
            body: 'Hola',
            timeLabel: '10:24',
            isCurrentUser: false,
          ),
        ),
      ),
    );

    expect(communityChatAuthorName(profile), 'Kimi Park');
    expect(find.text('Kimi Park'), findsOneWidget);
    expect(find.text('@kpark'), findsOneWidget);
    expect(find.textContaining('@'), findsOneWidget);
    expect(find.textContaining('.com'), findsNothing);
  });

  testWidgets('public profile reflects the actual follow relationship', (
    tester,
  ) async {
    final followService = _RelationshipFixture(following: false);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicProfileScreen(
          profile: _profile(),
          followService: followService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seguir'), findsOneWidget);
    await tester.ensureVisible(find.text('Seguir'));
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Siguiendo'), findsOneWidget);
    expect(followService.following, isTrue);
  });

  testWidgets('other-user profile uses the premium profile surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicProfileScreen(
          profile: _profile(),
          followService: _RelationshipFixture(following: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('public-profile-full')), findsOneWidget);
    expect(find.byType(HallyuBrandWordmark), findsOneWidget);
    expect(find.text('Seguir'), findsOneWidget);
    expect(find.text('Editar perfil'), findsNothing);
    expect(find.text('Crear'), findsNothing);
  });

  testWidgets('other-user profile uses the premium highlights deck', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicProfileScreen(
          profile: _profile(),
          currentUser: AuthUser(
            name: 'Viewer',
            username: '@viewer',
            email: 'viewer@example.test',
            avatarAsset: '',
            fandom: 'Multi fandom',
          ),
          followService: _RelationshipFixture(following: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-highlight-Top K-pop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-highlight-Conciertos')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-highlight-Bias')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-highlight-Photocards')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-highlight-Outfit')),
      findsOneWidget,
    );
    expect(find.byType(PremiumProfileHighlights), findsOneWidget);
    expect(find.byType(ProfileCategoryRail), findsNothing);
  });

  testWidgets('own public profile does not show a self-follow action', (
    tester,
  ) async {
    final profile = _profile(username: '@owner');
    final currentUser = AuthUser(
      name: 'Owner',
      username: '@owner',
      email: 'private@example.test',
      avatarAsset: '',
      fandom: 'Multi fandom',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicProfileScreen(
          profile: profile,
          currentUser: currentUser,
          followService: _RelationshipFixture(following: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seguir'), findsNothing);
    expect(find.text('Mensaje'), findsNothing);
  });

  testWidgets('public profile uses current branding and direct id lookup', (
    tester,
  ) async {
    final profile = _profile(
      id: 'ad5e7fd5-3588-4c77-98ca-b6df347c743a',
      name: 'Joel',
    );
    final followService = _ExactProfileFixture(profile);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicProfileScreen(
          profile: profile,
          followService: followService,
        ),
      ),
    );
    expect(find.byType(HallyuBrandIcon), findsOneWidget);
    expect(find.byType(HallyuBrandWordmark), findsOneWidget);
    expect(find.text('Perfil de Joel'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(followService.exactLookups, 1);
    expect(followService.searchLookups, 0);
  });

  testWidgets('returning while profile loads restores the previous route', (
    tester,
  ) async {
    final profile = _profile(
      id: 'ad5e7fd5-3588-4c77-98ca-b6df347c743a',
      name: 'Joel',
    );
    final followService = _DelayedProfileFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(
                    profile: profile,
                    followService: followService,
                  ),
                ),
              ),
              child: const Text('Pantalla de origen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pantalla de origen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('public-profile-full')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de origen'), findsOneWidget);
    followService.response.complete(profile);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
