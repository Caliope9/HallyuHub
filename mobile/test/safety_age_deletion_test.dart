import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/services/age_policy.dart';
import 'package:hallyuhub/src/services/content_safety_service.dart';
import 'package:hallyuhub/src/services/account_deletion_service.dart';
import 'package:hallyuhub/src/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('age gate blocks 15 and allows exactly 16, 17 and 18+', () {
    final now = DateTime(2026, 9, 10);
    expect(
      AgePolicy.validate(DateTime(2011, 9, 11), now: now),
      AgeGateResult.blocked,
    );
    expect(
      AgePolicy.validate(DateTime(2010, 9, 10), now: now),
      AgeGateResult.allowed,
    );
    expect(
      AgePolicy.validate(DateTime(2009, 9, 10), now: now),
      AgeGateResult.allowed,
    );
    expect(
      AgePolicy.validate(DateTime(2008, 9, 10), now: now),
      AgeGateResult.allowed,
    );
    expect(AgePolicy.isTeen(DateTime(2010, 9, 10), now: now), isTrue);
    expect(AgePolicy.isTeen(DateTime(2008, 9, 10), now: now), isFalse);
    expect(AgePolicy.ageAt(DateTime(2010, 9, 11), now: now), 15);
    expect(
      AgePolicy.validate(DateTime(2030, 1, 1), now: now),
      AgeGateResult.invalidBirthDate,
    );
    expect(AgePolicy.validate(null, now: now), AgeGateResult.missingBirthDate);
    expect(AgePolicy.ageAt(DateTime(2010, 9, 10), now: now), 16);
  });

  test('registration requires a real birth date', () async {
    expect(
      () => const LocalAuthService().register(
        name: 'Test User',
        username: 'test-user',
        email: 'test-user@hallyuhub.app',
        password: 'password-2026',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('Auth Hook registration errors are translated into clear Spanish', () {
    expect(
      registrationAgeErrorMessageForTesting('birth_date is required'),
      'Ingresá tu fecha de nacimiento para crear la cuenta.',
    );
    expect(
      registrationAgeErrorMessageForTesting('birth_date is invalid'),
      'Ingresá una fecha de nacimiento válida.',
    );
    expect(
      registrationAgeErrorMessageForTesting(
        'HallyuHub is available from age 16',
      ),
      'Debes tener al menos 16 años para crear una cuenta en HallyuHub.',
    );
  });

  test('birth date metadata is complete and date-only', () {
    expect(birthDateMetadataValue(DateTime(2010, 9, 10)), '2010-09-10');
  });

  test(
    'content safety is unavailable without a provider, never safe',
    () async {
      final result = await const ContentSafetyService().classify(
        contentType: 'image',
        content: 'anything',
      );
      expect(result.verdict, ContentSafetyVerdict.unavailable);
      expect(result.canPublish, isFalse);
    },
  );

  test(
    'deletion request is recoverable for 30 days but not when completed',
    () {
      final requested = DateTime.now().toUtc();
      final request = AccountDeletionRequest(
        id: 'test',
        status: AccountDeletionStatus.pending,
        requestedAt: requested,
        reviewedAt: null,
        completedAt: null,
        canceledAt: null,
        requestedScope: '',
        exportRequested: false,
        recoverableUntil: requested.add(const Duration(days: 30)),
      );
      expect(request.canCancel, isTrue);
      expect(
        request.recoverableUntil!.difference(request.requestedAt),
        const Duration(days: 30),
      );
      final completed = AccountDeletionRequest(
        id: 'test',
        status: AccountDeletionStatus.completed,
        requestedAt: requested,
        reviewedAt: null,
        completedAt: requested,
        canceledAt: null,
        requestedScope: '',
        exportRequested: false,
        recoverableUntil: request.recoverableUntil,
      );
      expect(completed.canCancel, isFalse);
    },
  );
}
