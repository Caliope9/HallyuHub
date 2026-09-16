import 'package:flutter/foundation.dart';

import '../models.dart';

class LocalNotificationService {
  const LocalNotificationService();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealNotifications => false;

  Future<List<HallyuNotification>> restoreNotifications({
    int limit = 80,
  }) async {
    return const [];
  }

  Future<int> unreadCount() async => 0;

  Future<void> markRead(String notificationId) async {}

  Future<void> markAllRead() async {}
}
