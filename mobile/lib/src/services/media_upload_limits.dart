import 'dart:typed_data';

class MediaUploadLimits {
  const MediaUploadLimits._();

  static const int mebibyte = 1024 * 1024;

  static const int imageBytes = 10 * mebibyte;
  static const int avatarBytes = 5 * mebibyte;
  static const int postVideoBytes = 100 * mebibyte;
  static const int storyVideoBytes = 50 * mebibyte;
  static const int dropVideoBytes = 100 * mebibyte;
  static const int fancamVideoBytes = 100 * mebibyte;
  static const int messageImageBytes = 10 * mebibyte;
  static const int messageVideoBytes = 50 * mebibyte;

  static const int maxPostMediaItems = 6;
  static const int storyVideoDurationSeconds = 60;
  static const int dropVideoDurationSeconds = 5 * 60;
  static const int fancamVideoDurationSeconds = 5 * 60;

  static String? detectImageContentType(Uint8List bytes) {
    if (bytes.length > 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 12 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }
}
