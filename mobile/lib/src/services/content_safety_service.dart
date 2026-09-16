enum ContentSafetyVerdict { safe, unsafe, needsReview, unavailable }

enum ProhibitedContentCategory {
  explicitSexual,
  sexualExploitation,
  extremeGore,
  extremeGraphicViolence,
}

class ContentSafetyResult {
  const ContentSafetyResult({
    required this.verdict,
    this.categories = const {},
    this.provider = '',
    this.reason = '',
  });

  final ContentSafetyVerdict verdict;
  final Set<ProhibitedContentCategory> categories;
  final String provider;
  final String reason;

  bool get canPublish => verdict == ContentSafetyVerdict.safe;
}

abstract class ContentSafetyProvider {
  Future<ContentSafetyResult> classify({
    required String contentType,
    required String content,
    String mediaUrl = '',
  });
}

/// Automatic moderation is deliberately fail-closed: without a configured
/// provider, content is unavailable for classification, never silently safe.
class ContentSafetyService {
  const ContentSafetyService({this.provider});

  final ContentSafetyProvider? provider;

  Future<ContentSafetyResult> classify({
    required String contentType,
    required String content,
    String mediaUrl = '',
  }) async {
    final configured = provider;
    if (configured == null) {
      return const ContentSafetyResult(
        verdict: ContentSafetyVerdict.unavailable,
        reason: 'No hay un proveedor automático configurado.',
      );
    }
    try {
      final result = await configured.classify(
        contentType: contentType,
        content: content,
        mediaUrl: mediaUrl,
      );
      if (result.verdict == ContentSafetyVerdict.safe &&
          result.categories.isNotEmpty) {
        return ContentSafetyResult(
          verdict: ContentSafetyVerdict.needsReview,
          categories: result.categories,
          provider: result.provider,
          reason: 'El proveedor devolvió categorías restringidas.',
        );
      }
      return result;
    } catch (_) {
      return const ContentSafetyResult(
        verdict: ContentSafetyVerdict.unavailable,
        reason: 'El proveedor no está disponible.',
      );
    }
  }
}
