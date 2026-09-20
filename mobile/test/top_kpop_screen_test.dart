import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/top_kpop_screen.dart';
import 'package:hallyuhub/src/services/local_artist_tag_service.dart';
import 'package:hallyuhub/src/services/local_chat_service.dart';
import 'package:hallyuhub/src/services/local_content_category_service.dart';
import 'package:hallyuhub/src/services/local_drop_service.dart';
import 'package:hallyuhub/src/services/local_fancam_service.dart';
import 'package:hallyuhub/src/services/local_follow_service.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';
import 'package:hallyuhub/src/services/local_safety_service.dart';
import 'package:hallyuhub/src/services/local_story_service.dart';
import 'package:hallyuhub/src/services/local_user_tag_service.dart';
import 'package:hallyuhub/src/services/store_profile_service.dart';
import 'package:hallyuhub/src/services/top_kpop_service.dart';

class _FakeTopKpopService implements TopKpopService {
  final calls = <({TopKpopType type, int limit, int offset})>[];

  @override
  Future<List<TopKpopEntry>> restorePage({
    required TopKpopType type,
    required int limit,
    required int offset,
  }) async {
    calls.add((type: type, limit: limit, offset: offset));
    if (type == TopKpopType.groups) {
      return offset == 0
          ? [
              _entry('bts', 'group', 'BTS', 3),
              _entry('enhypen', 'group', 'ENHYPEN', 3),
            ]
          : const [];
    }
    return offset == 0
        ? [
            _entry('artist', 'artist', 'A Artist', 5, following: true),
            _entry('idol', 'idol', 'B Idol', 5),
          ]
        : const [];
  }

  static TopKpopEntry _entry(
    String id,
    String type,
    String name,
    int count, {
    bool following = false,
  }) {
    return TopKpopEntry(
      entityId: id,
      entityType: type,
      name: name,
      imageUrl: '',
      isVerified: true,
      followerCount: count,
      isFollowing: following,
    );
  }
}

class _PagingTopKpopService implements TopKpopService {
  final calls = <int>[];

  @override
  Future<List<TopKpopEntry>> restorePage({
    required TopKpopType type,
    required int limit,
    required int offset,
  }) async {
    calls.add(offset);
    if (offset == 0) {
      return [
        for (var index = 0; index < 20; index++)
          _FakeTopKpopService._entry(
            'entity-$index',
            'group',
            'Group $index',
            20 - index,
          ),
      ];
    }
    return [_FakeTopKpopService._entry('entity-20', 'group', 'Group 20', 1)];
  }
}

AuthUser _user() => const AuthUser(
  name: 'Fan',
  username: '@fan',
  email: 'fan@example.com',
  avatarAsset: 'assets/brand/hallyu_hub_logo.png',
  fandom: 'K-pop',
);

Widget _screen(
  _FakeTopKpopService service, {
  Future<void> Function(TopKpopEntry, bool)? onFollow,
  ValueChanged<TopKpopEntry>? onOpenEntity,
}) {
  return MaterialApp(
    home: TopKpopScreen(
      user: _user(),
      topKpopService: service,
      onFollow: onFollow,
      onOpenEntity: onOpenEntity,
      artistTagService: const LocalArtistTagService(),
      postService: const LocalPostService(),
      storyService: const LocalStoryService(),
      dropService: const LocalDropService(),
      fancamService: const LocalFancamService(),
      followService: const LocalFollowService(),
      chatService: const LocalChatService(),
      contentCategoryService: const LocalContentCategoryService(),
      userTagService: const LocalUserTagService(),
      safetyService: const LocalSafetyService(),
      storeProfileService: const LocalStoreProfileService(),
    ),
  );
}

void main() {
  test(
    'Top K-pop SQL contract filters verified entities and both artist types',
    () {
      final sql = File('docs/supabase_top_kpop_v1.sql').readAsStringSync();
      expect(sql, contains("e.status = 'verified'"));
      expect(sql, contains("e.entity_type in ('artist', 'idol')"));
      expect(sql, contains('ranked.follower_count desc'));
      expect(sql, contains('ranked.name asc'));
      expect(sql, contains('ranked.entity_id asc'));
    },
  );

  test('TopKpopEntry parses real follower count and entity type', () {
    final entry = TopKpopEntry.fromRow({
      'entity_id': 'entity-1',
      'entity_type': 'idol',
      'name': 'Jimin',
      'image_url': '',
      'is_verified': true,
      'follower_count': '12',
      'is_following': true,
    });

    expect(entry.entityType, 'idol');
    expect(entry.followerCount, 12);
    expect(entry.isFollowing, isTrue);
  });

  testWidgets('groups tab renders group ranking and stable tie order', (
    tester,
  ) async {
    final service = _FakeTopKpopService();
    await tester.pumpWidget(_screen(service));
    await tester.pumpAndSettle();

    expect(find.text('Top K-pop'), findsOneWidget);
    expect(find.text('BTS'), findsOneWidget);
    expect(find.text('ENHYPEN'), findsOneWidget);
    expect(find.text('3 seguidores'), findsNWidgets(2));
    expect(service.calls.single.type, TopKpopType.groups);
    expect(service.calls.single.limit, 20);
    expect(service.calls.single.offset, 0);
  });

  testWidgets('artists tab includes artist and idol and follow updates', (
    tester,
  ) async {
    final service = _FakeTopKpopService();
    TopKpopEntry? followed;
    var following = false;
    await tester.pumpWidget(
      _screen(
        service,
        onFollow: (entry, next) async {
          followed = entry;
          following = next;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-kpop-tab-artists')));
    await tester.pumpAndSettle();

    expect(find.text('A Artist'), findsOneWidget);
    expect(find.text('B Idol'), findsOneWidget);
    expect(find.text('Siguiendo'), findsOneWidget);
    expect(find.text('Seguir'), findsOneWidget);
    await tester.tap(find.text('Seguir'));
    expect(followed?.entityId, 'idol');
    expect(following, isTrue);
    expect(service.calls.last.type, TopKpopType.artists);
  });

  testWidgets('ranking row opens the existing entity profile', (tester) async {
    final service = _FakeTopKpopService();
    TopKpopEntry? opened;
    await tester.pumpWidget(
      _screen(service, onOpenEntity: (entry) => opened = entry),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BTS'));
    await tester.pump();

    expect(opened?.entityId, 'bts');
  });

  testWidgets('ranking requests the next page with a stable offset', (
    tester,
  ) async {
    final service = _PagingTopKpopService();
    await tester.pumpWidget(
      MaterialApp(
        home: TopKpopScreen(
          user: _user(),
          topKpopService: service,
          artistTagService: const LocalArtistTagService(),
          postService: const LocalPostService(),
          storyService: const LocalStoryService(),
          dropService: const LocalDropService(),
          fancamService: const LocalFancamService(),
          followService: const LocalFollowService(),
          chatService: const LocalChatService(),
          contentCategoryService: const LocalContentCategoryService(),
          userTagService: const LocalUserTagService(),
          safetyService: const LocalSafetyService(),
          storeProfileService: const LocalStoreProfileService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(service.calls, contains(20));
  });
}
