import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists only the opt-out flags for Hally's contextual tips.
class HallyFeatureTipService {
  const HallyFeatureTipService();

  static const keyPrefix = 'hallyuhub.feature-tip.disabled.';
  static final Set<String> _dismissedThisSession = <String>{};
  static final List<Future<void> Function()> _popupQueue = [];
  static bool _processingPopupQueue = false;

  bool wasDismissedThisSession(String featureId) =>
      _dismissedThisSession.contains(featureId);

  void dismissForSession(String featureId) {
    _dismissedThisSession.add(featureId);
  }

  void enqueuePopup(Future<void> Function() showPopup) {
    _popupQueue.add(showPopup);
    if (_processingPopupQueue) return;
    unawaited(_drainPopupQueue());
  }

  static Future<void> _drainPopupQueue() async {
    if (_processingPopupQueue) return;
    _processingPopupQueue = true;
    try {
      while (_popupQueue.isNotEmpty) {
        final showPopup = _popupQueue.removeAt(0);
        await showPopup();
      }
    } finally {
      _processingPopupQueue = false;
      if (_popupQueue.isNotEmpty) unawaited(_drainPopupQueue());
    }
  }

  static void clearSessionDismissalsForTesting() {
    _dismissedThisSession.clear();
    _popupQueue.clear();
  }

  Future<bool> isDisabled(String featureId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(featureId)) ?? false;
  }

  Future<void> disable(String featureId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(featureId), true);
  }

  Future<void> resetAll() async {
    _dismissedThisSession.clear();
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where(
      (key) => key.startsWith(keyPrefix),
    );
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  String _key(String featureId) => '$keyPrefix$featureId';
}
