import 'package:flutter/foundation.dart';

class VideoAudioPreference {
  const VideoAudioPreference._();

  static final ValueNotifier<bool> muted = ValueNotifier<bool>(true);

  static void setMuted(bool value, {required String source}) {
    debugPrint(
      'VIDEO_MUTED_STATE source=$source previous=${muted.value} muted=$value',
    );
    if (muted.value == value) return;
    muted.value = value;
    debugPrint('VIDEO_AUDIO_STATE source=$source muted=$value');
  }
}
