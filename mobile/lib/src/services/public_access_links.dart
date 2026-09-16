import '../data/legal_documents.dart';

bool isPublicAccessPath(String path) {
  final normalized = path.replaceAll(RegExp(r'/+$'), '');
  return normalized == '/acceso' || normalized == '/beta';
}

String canonicalPublicAccessShareUrl({
  String referralCode = '',
  String existingUrl = '',
}) {
  var normalizedReferralCode = referralCode.trim();
  final normalizedExistingUrl = existingUrl.trim();

  if (normalizedReferralCode.isEmpty && normalizedExistingUrl.isNotEmpty) {
    normalizedReferralCode =
        Uri.tryParse(normalizedExistingUrl)?.queryParameters['ref']?.trim() ??
        '';
  }

  if (normalizedReferralCode.isEmpty && normalizedExistingUrl.isEmpty) {
    return '';
  }

  final accessUri = Uri.parse(publicAccessUrl);
  if (normalizedReferralCode.isEmpty) return accessUri.toString();
  return accessUri
      .replace(queryParameters: {'ref': normalizedReferralCode})
      .toString();
}
