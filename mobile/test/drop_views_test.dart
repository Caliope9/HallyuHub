import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/drops_screen.dart';
import 'package:hallyuhub/src/services/drop_view_tracking.dart';

void main() {
  test('Drop viewCount defaults to zero', () {
    const drop = DropClip(
      title: 'Dance clip',
      artist: 'Artist',
      creator: '@fan',
      audio: 'Original',
      imageAsset: 'assets/demo-posts/post-01.jpg',
      views: 'legacy',
      likes: '0',
    );

    expect(drop.viewCount, 0);
  });

  test('Drop view counts use compact presentation notation', () {
    expect(formatDropViewCount(999), '999');
    expect(formatDropViewCount(1200), '1.2K');
    expect(formatDropViewCount(48000), '48K');
    expect(formatDropViewCount(1100000), '1.1M');
  });

  test('Drop playback records only after three effective seconds', () {
    final tracker = DropViewSessionTracker();
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

  test('short Drop videos record near completion and remain idempotent', () {
    final tracker = DropViewSessionTracker();
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

  test('each Drop playback session gets a UUID-shaped identifier', () {
    final first = newDropPlaybackSessionId();
    final second = newDropPlaybackSessionId();

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
