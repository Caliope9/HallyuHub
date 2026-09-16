import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class StoryAudioController {
  final AudioPlayer _player = AudioPlayer();
  String _activeAsset = '';
  bool _paused = false;
  String? _lastError;

  String get activeAsset => _activeAsset;
  bool get isPlaying => _activeAsset.isNotEmpty && !_paused;
  bool get isPaused => _activeAsset.isNotEmpty && _paused;
  String? get lastError => _lastError;

  Future<void> play(String assetPath) async {
    if (assetPath.isEmpty) {
      await stop();
      return;
    }
    try {
      _lastError = null;
      if (_activeAsset == assetPath) {
        _paused = false;
        await _player.resume();
        return;
      }
      await _player.stop();
      _activeAsset = assetPath;
      _paused = false;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
    } catch (error) {
      _activeAsset = '';
      _paused = false;
      _lastError = '$error';
    }
  }

  Future<void> pause() async {
    if (_activeAsset.isEmpty || _paused) return;
    try {
      await _player.pause();
      _paused = true;
      _lastError = null;
    } catch (error) {
      _lastError = '$error';
    }
  }

  Future<void> resume() async {
    if (_activeAsset.isEmpty || !_paused) return;
    try {
      await _player.resume();
      _paused = false;
      _lastError = null;
    } catch (error) {
      _lastError = '$error';
    }
  }

  Future<void> stop() async {
    _activeAsset = '';
    _paused = false;
    try {
      await _player.stop();
      _lastError = null;
    } catch (error) {
      _lastError = '$error';
    }
  }

  void dispose() {
    unawaited(_player.dispose());
  }
}
