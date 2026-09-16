import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaAccessResult {
  ready,
  unavailable,
  denied,
  settingsRequired,
  restricted,
}

class MediaPermissionService {
  const MediaPermissionService();

  Future<MediaAccessResult> requestSystemAccess() async {
    return requestCameraAccess(microphone: true);
  }

  Future<MediaAccessResult> requestCameraAccess({
    bool microphone = false,
  }) async {
    if (kIsWeb) return MediaAccessResult.ready;
    final cameraResult = await _request(Permission.camera);
    if (cameraResult != MediaAccessResult.ready) return cameraResult;
    if (!microphone) return MediaAccessResult.ready;
    return requestMicrophoneAccess();
  }

  Future<MediaAccessResult> cameraStatus({bool microphone = false}) async {
    if (kIsWeb) return MediaAccessResult.ready;
    final cameraResult = await _status(Permission.camera);
    if (cameraResult != MediaAccessResult.ready || !microphone) {
      return cameraResult;
    }
    return microphoneStatus();
  }

  Future<MediaAccessResult> requestMicrophoneAccess() async {
    if (kIsWeb) return MediaAccessResult.ready;
    return _request(Permission.microphone);
  }

  Future<MediaAccessResult> microphoneStatus() async {
    if (kIsWeb) return MediaAccessResult.ready;
    return _status(Permission.microphone);
  }

  Future<MediaAccessResult> requestGalleryAccess() async {
    // Android's system Photo Picker grants access only to the selected items.
    // It does not require broad library/storage permission.
    return MediaAccessResult.ready;
  }

  Future<MediaAccessResult> galleryStatus() async {
    // The platform picker handles scoped access when the user selects media.
    return MediaAccessResult.ready;
  }

  Future<MediaAccessResult> requestLocationAccess() async {
    return MediaAccessResult.unavailable;
  }

  Future<MediaAccessResult> locationStatus() async {
    return MediaAccessResult.unavailable;
  }

  Future<MediaAccessResult> requestNotificationsAccess() async {
    return MediaAccessResult.unavailable;
  }

  Future<MediaAccessResult> notificationsStatus() async {
    return MediaAccessResult.unavailable;
  }

  Future<bool> openSettings() => openAppSettings();

  Future<MediaAccessResult> _request(Permission permission) async {
    try {
      final current = await _status(permission);
      if (current == MediaAccessResult.ready ||
          current == MediaAccessResult.settingsRequired ||
          current == MediaAccessResult.restricted) {
        return current;
      }
      return _resultFor(await permission.request());
    } catch (_) {
      return MediaAccessResult.unavailable;
    }
  }

  Future<MediaAccessResult> _status(Permission permission) async {
    try {
      return _resultFor(await permission.status);
    } catch (_) {
      return MediaAccessResult.unavailable;
    }
  }

  MediaAccessResult _resultFor(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MediaAccessResult.ready;
    if (status.isPermanentlyDenied) return MediaAccessResult.settingsRequired;
    if (status.isRestricted) return MediaAccessResult.restricted;
    return MediaAccessResult.denied;
  }
}
