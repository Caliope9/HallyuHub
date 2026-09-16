import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/services/video_playback_coordinator.dart';

void main() {
  setUp(VideoPlaybackCoordinator.resetForTesting);

  test('claiming a video pauses the previously active video', () async {
    final firstOwner = Object();
    final secondOwner = Object();
    var firstPauseCount = 0;

    expect(
      await VideoPlaybackCoordinator.claim(
        owner: firstOwner,
        source: 'first',
        pause: () async => firstPauseCount++,
      ),
      isTrue,
    );
    expect(
      await VideoPlaybackCoordinator.claim(
        owner: secondOwner,
        source: 'second',
        pause: () async {},
      ),
      isTrue,
    );

    expect(firstPauseCount, 1);
    expect(VideoPlaybackCoordinator.hasActivePlayback, isTrue);
  });

  test('pauseActive stops and clears the current video', () async {
    final owner = Object();
    var pauseCount = 0;
    await VideoPlaybackCoordinator.claim(
      owner: owner,
      source: 'drop',
      pause: () async => pauseCount++,
    );

    await VideoPlaybackCoordinator.pauseActive(reason: 'tab_changed');

    expect(pauseCount, 1);
    expect(VideoPlaybackCoordinator.hasActivePlayback, isFalse);
  });

  test('an interrupted claim cannot start stale playback', () async {
    final firstOwner = Object();
    final secondOwner = Object();
    final firstPause = Completer<void>();
    await VideoPlaybackCoordinator.claim(
      owner: firstOwner,
      source: 'first',
      pause: () => firstPause.future,
    );

    final secondClaim = VideoPlaybackCoordinator.claim(
      owner: secondOwner,
      source: 'second',
      pause: () async {},
    );
    VideoPlaybackCoordinator.release(secondOwner);
    firstPause.complete();

    expect(await secondClaim, isFalse);
    expect(VideoPlaybackCoordinator.hasActivePlayback, isFalse);
  });
}
