import 'dart:async';

import 'package:flutter/material.dart';

typedef VideoPlaybackPause = Future<void> Function();

class VideoPlaybackCoordinator {
  const VideoPlaybackCoordinator._();

  static Object? _activeOwner;
  static VideoPlaybackPause? _activePause;
  static int _claimRevision = 0;

  static Future<bool> claim({
    required Object owner,
    required VideoPlaybackPause pause,
    required String source,
  }) async {
    if (identical(_activeOwner, owner)) {
      _activePause = pause;
      return true;
    }

    final revision = ++_claimRevision;
    final previousPause = _activePause;
    _activeOwner = owner;
    _activePause = pause;

    if (previousPause != null) {
      try {
        await previousPause();
      } catch (error) {
        debugPrint(
          'VIDEO_PLAYBACK_COORDINATOR_ERROR action=pause_previous '
          'source=$source error=$error',
        );
      }
    }

    return revision == _claimRevision && identical(_activeOwner, owner);
  }

  static void release(Object owner) {
    if (!identical(_activeOwner, owner)) return;
    _claimRevision++;
    _activeOwner = null;
    _activePause = null;
  }

  static Future<void> pauseActive({required String reason}) async {
    final pause = _activePause;
    if (_activeOwner == null || pause == null) return;

    _claimRevision++;
    _activeOwner = null;
    _activePause = null;
    try {
      await pause();
      debugPrint('VIDEO_PLAYBACK_PAUSED reason=$reason');
    } catch (error) {
      debugPrint(
        'VIDEO_PLAYBACK_COORDINATOR_ERROR action=pause_active '
        'reason=$reason error=$error',
      );
    }
  }

  @visibleForTesting
  static bool get hasActivePlayback => _activeOwner != null;

  @visibleForTesting
  static void resetForTesting() {
    _claimRevision++;
    _activeOwner = null;
    _activePause = null;
  }
}

class VideoPlaybackNavigatorObserver extends NavigatorObserver {
  void _pause(String reason) {
    unawaited(VideoPlaybackCoordinator.pauseActive(reason: reason));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) _pause('route_push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _pause('route_pop');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _pause('route_remove');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _pause('route_replace');
  }
}

final videoPlaybackNavigatorObserver = VideoPlaybackNavigatorObserver();
