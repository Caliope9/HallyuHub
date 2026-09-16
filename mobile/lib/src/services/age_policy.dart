import 'package:flutter/foundation.dart';

enum AgeGateResult { allowed, blocked, missingBirthDate, invalidBirthDate }

class AgePolicy {
  const AgePolicy._();

  static const minimumAge = 16;
  static const teenMaximumAge = 17;

  static int? ageAt(DateTime birthDate, {DateTime? now}) {
    final today = (now ?? DateTime.now()).toLocal();
    final birth = birthDate.toLocal();
    if (birth.isAfter(today)) return null;
    var age = today.year - birth.year;
    final hadBirthday = today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthday) age--;
    return age < 0 ? null : age;
  }

  static AgeGateResult validate(DateTime? birthDate, {DateTime? now}) {
    if (birthDate == null) return AgeGateResult.missingBirthDate;
    final age = ageAt(birthDate, now: now);
    if (age == null) return AgeGateResult.invalidBirthDate;
    return age >= minimumAge ? AgeGateResult.allowed : AgeGateResult.blocked;
  }

  static bool isTeen(DateTime? birthDate, {DateTime? now}) {
    final age = birthDate == null ? null : ageAt(birthDate, now: now);
    return age != null && age >= minimumAge && age <= teenMaximumAge;
  }

  static String format(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

@visibleForTesting
DateTime agePolicyToday() => DateTime.now();
