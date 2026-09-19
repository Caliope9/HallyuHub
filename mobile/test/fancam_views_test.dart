import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/screens/fancams_screen.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/services/fancam_view_tracking.dart';

void main() {
  test('view counts use compact social-feed notation', () {
    expect(formatFancamViewCount(999), '999');
    expect(formatFancamViewCount(1200), '1.2K');
    expect(formatFancamViewCount(48000), '48K');
    expect(formatFancamViewCount(1100000), '1.1M');
  });

  test('Fancam viewCount defaults to zero', () {
    const fancam = Fancam(
      title: 'Stage focus',
      artist: 'Artist',
      creator: '@fan',
      imageAsset: 'assets/demo-posts/post-01.jpg',
      duration: '00:30',
      energy: 'New',
    );

    expect(fancam.viewCount, 0);
  });

  test('a playback session records only after three effective seconds', () {
    final tracker = FancamViewSessionTracker();
    tracker.start();

    expect(
      tracker.shouldRecord(
        position: const Duration(seconds: 2, milliseconds: 999),
        duration: const Duration(seconds: 30),
      ),
      isFalse,
    );
    expect(
      tracker.shouldRecord(
        position: const Duration(seconds: 3),
        duration: const Duration(seconds: 30),
      ),
      isTrue,
    );
    expect(
      tracker.shouldRecord(
        position: const Duration(seconds: 4),
        duration: const Duration(seconds: 30),
      ),
      isFalse,
    );
  });

  test('short videos record near completion and remain idempotent', () {
    final tracker = FancamViewSessionTracker();
    tracker.start();

    expect(
      tracker.shouldRecord(
        position: const Duration(seconds: 1, milliseconds: 800),
        duration: const Duration(seconds: 2),
      ),
      isFalse,
    );
    expect(
      tracker.shouldRecord(
        position: const Duration(seconds: 1, milliseconds: 901),
        duration: const Duration(seconds: 2),
      ),
      isTrue,
    );
    expect(tracker.recorded, isTrue);
    expect(
      tracker.shouldRecord(
        position: const Duration(seconds: 1, milliseconds: 950),
        duration: const Duration(seconds: 2),
      ),
      isFalse,
    );
  });

  test('new playback sessions get UUID-shaped identifiers', () {
    final first = newFancamPlaybackSessionId();
    final second = newFancamPlaybackSessionId();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, isNot(first));
  });
}
