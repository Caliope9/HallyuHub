import 'dart:math';

String newDropPlaybackSessionId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

class DropViewSessionTracker {
  DropViewSessionTracker({this.minimumPlayback = const Duration(seconds: 3)});

  final Duration minimumPlayback;
  bool _recorded = false;

  bool get recorded => _recorded;

  void start() => _recorded = false;

  bool shouldRecord({required Duration position, required Duration duration}) {
    if (_recorded || duration <= Duration.zero) return false;
    final threshold = duration < minimumPlayback
        ? duration - const Duration(milliseconds: 100)
        : minimumPlayback;
    if (threshold <= Duration.zero || position < threshold) return false;
    _recorded = true;
    return true;
  }
}
