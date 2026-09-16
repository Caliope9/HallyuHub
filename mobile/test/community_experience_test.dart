import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/data/discover_data.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/public_profile_screen.dart';
import 'package:hallyuhub/src/services/local_follow_service.dart';
import 'package:hallyuhub/src/utils/community_membership_sections.dart';
import 'package:hallyuhub/src/widgets/community_chat_message_tile.dart';
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
}
