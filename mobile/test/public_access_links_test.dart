import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/services/public_access_links.dart';

void main() {
  group('public access routing', () {
    test('accepts the canonical route and the legacy alias', () {
      expect(isPublicAccessPath('/acceso'), isTrue);
      expect(isPublicAccessPath('/acceso/'), isTrue);
      expect(isPublicAccessPath('/beta'), isTrue);
      expect(isPublicAccessPath('/beta/'), isTrue);
      expect(isPublicAccessPath('/'), isFalse);
    });

    test('builds canonical referral links', () {
      expect(
        canonicalPublicAccessShareUrl(referralCode: 'CODIGO'),
        'https://www.hallyuhub.net/acceso?ref=CODIGO',
      );
    });

    test('converts legacy backend links and preserves the referral', () {
      expect(
        canonicalPublicAccessShareUrl(
          existingUrl: 'https://www.hallyuhub.net/beta?ref=LEGACY',
        ),
        'https://www.hallyuhub.net/acceso?ref=LEGACY',
      );
    });
  });
}
