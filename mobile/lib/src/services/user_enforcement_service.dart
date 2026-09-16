enum EnforcementAction { warning, restriction, suspension, ban }

class UserEnforcementDecision {
  const UserEnforcementDecision({
    required this.action,
    required this.reason,
    this.until,
  });

  final EnforcementAction action;
  final String reason;
  final DateTime? until;
}

class UserEnforcementService {
  const UserEnforcementService();

  UserEnforcementDecision decide({
    required EnforcementAction action,
    required String reason,
    DateTime? until,
  }) {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Debe explicar la medida.');
    }
    if ((action == EnforcementAction.suspension ||
            action == EnforcementAction.ban) &&
        until != null &&
        until.isBefore(DateTime.now())) {
      throw ArgumentError.value(until, 'until', 'La fecha ya pasó.');
    }
    return UserEnforcementDecision(action: action, reason: reason.trim(), until: until);
  }
}
