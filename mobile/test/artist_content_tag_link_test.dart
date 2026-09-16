import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/kpop_entity_profile_screen.dart';
import 'package:hallyuhub/src/services/local_artist_tag_service.dart';
import 'package:hallyuhub/src/services/local_chat_service.dart';
import 'package:hallyuhub/src/services/local_content_category_service.dart';
import 'package:hallyuhub/src/services/local_drop_service.dart';
import 'package:hallyuhub/src/services/local_fancam_service.dart';
import 'package:hallyuhub/src/services/local_follow_service.dart';
import 'package:hallyuhub/src/services/local_post_service.dart';
import 'package:hallyuhub/src/services/local_story_service.dart';
import 'package:hallyuhub/src/services/local_user_tag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bts = KpopEntity(
  id: 'bts-entity-id',
  type: KpopEntityType.group,
  name: 'BTS',
);

const _taggedPost = HubPost(
  id: 'post-tagged-bts',
  author: 'Fan',
  username: '@fan',
  avatarAsset: '',
  imageAsset: '',
  caption: 'Concierto BTS',
  tags: [],
  likes: '0',
  comments: '0',
  mood: '',
  time: 'Ahora',
  shares: '0',
  saves: '0',
);

const _untaggedPost = HubPost(
  id: 'post-untagged',
  author: 'Fan',
  username: '@fan',
  avatarAsset: '',
  imageAsset: '',
  caption: 'Publicación sin etiqueta',
  tags: [],
  likes: '0',
  comments: '0',
  mood: '',
  time: 'Ahora',
  shares: '0',
  saves: '0',
);

class _PostsWithTaggedContent extends LocalPostService {
  const _PostsWithTaggedContent();

  @override
  Future<List<HubPost>> restorePosts({
    int limit = 60,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    bool homeFeed = false,
    Set<String> followedAuthorIds = const {},
    Set<String> followedEntityIds = const {},
  }) async => const [_taggedPost, _untaggedPost];
}

class _TagsForTaggedPost extends LocalArtistTagService {
  const _TagsForTaggedPost();

  @override
  Future<Map<String, List<ContentArtistTag>>> restoreForContents({
    required ProfileContentType contentType,
    required Iterable<String> contentIds,
  }) async {
    if (contentType != ProfileContentType.post) return const {};
    return {
      'post-tagged-bts': [
        ContentArtistTag(
          contentType: ProfileContentType.post,
          contentId: 'post-tagged-bts',
          entityId: _bts.id,
          taggedBy: 'fan-id',
          entity: _bts,
        ),
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('post tags persist and restore the real entity id', () async {
    const service = LocalArtistTagService();
    await service.saveContentArtistTags(
      contentType: ProfileContentType.post,
      contentId: 'post-1',
      entities: [_bts],
    );
    final tags = await service.restoreForContent(
      contentType: ProfileContentType.post,
      contentId: 'post-1',
    );
    expect(tags.single.entityId, _bts.id);
    expect(tags.single.entity?.name, 'BTS');
  });

  testWidgets(
    'the entity page shows tagged real posts and excludes untagged posts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: KpopEntityProfileScreen(
            entity: _bts,
            currentUser: null,
            artistTagService: _TagsForTaggedPost(),
            postService: _PostsWithTaggedContent(),
            storyService: LocalStoryService(),
            dropService: LocalDropService(),
            fancamService: LocalFancamService(),
            followService: LocalFollowService(),
            chatService: LocalChatService(),
            contentCategoryService: LocalContentCategoryService(),
            userTagService: LocalUserTagService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Concierto BTS'), findsOneWidget);
      expect(find.text('Publicación sin etiqueta'), findsNothing);
    },
  );
}
