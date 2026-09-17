import 'package:flutter_test/flutter_test.dart';

import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/services/repost_service.dart';

void main() {
  test('story audience values have stable labels and storage values', () {
    expect(StoryAudienceType.publicAudience.label, 'Todos');
    expect(StoryAudienceType.followers.storageValue, 'followers');
    expect(StoryAudienceType.closeFriends.storageValue, 'close_friends');
    expect(StoryAudienceType.exclude.storageValue, 'exclude');
    expect(StoryAudienceType.include.storageValue, 'include');
    expect(
      StoryAudienceType.fromStorage('unknown'),
      StoryAudienceType.followers,
    );
  });

  test('story draft preserves audience and shared content reference', () {
    const draft = StoryDraft(
      type: StoryContentType.image,
      audienceType: StoryAudienceType.include,
      audienceUserIds: ['user-b'],
      sharedContentType: 'post',
      sharedContentId: 'post-1',
    );
    final copy = draft.copyWith(audienceType: StoryAudienceType.exclude);

    expect(copy.audienceType, StoryAudienceType.exclude);
    expect(copy.audienceUserIds, ['user-b']);
    expect(copy.sharedContentType, 'post');
    expect(copy.sharedContentId, 'post-1');
  });

  test('local reposts are idempotent and removable', () async {
    final service = LocalRepostService();
    final first = await service.createRepost(
      contentType: RepostContentType.post,
      contentId: 'post-1',
    );
    final second = await service.createRepost(
      contentType: RepostContentType.post,
      contentId: 'post-1',
    );

    expect(second.id, first.id);
    expect(service.contains(RepostContentType.post, 'post-1'), isTrue);

    await service.removeRepost(
      contentType: RepostContentType.post,
      contentId: 'post-1',
    );
    expect(service.contains(RepostContentType.post, 'post-1'), isFalse);
  });
}
