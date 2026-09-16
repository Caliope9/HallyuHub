import '../models.dart';

String storyRelativeTime(Story story, {DateTime? now}) {
  final createdAt = story.createdAt;
  if (createdAt != null) {
    return relativeTimeFrom(createdAt, now: now);
  }
  final fallback = story.timeLabel.trim();
  if (fallback.isEmpty || fallback.toLowerCase() == 'ahora') {
    return 'hace 1 min';
  }
  return fallback[0].toLowerCase() + fallback.substring(1);
}

String relativeTimeFrom(DateTime createdAt, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(createdAt);
  if (difference.inHours >= 24) {
    final days = difference.inDays.clamp(1, 9999);
    return days == 1 ? 'hace 1 día' : 'hace $days días';
  }
  if (difference.inHours >= 1) {
    return 'hace ${difference.inHours} h';
  }
  return 'hace ${difference.inMinutes.clamp(1, 59)} min';
}

String memoryLabelFor(DateTime originalCreatedAt, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(originalCreatedAt);
  final days = difference.inDays;
  if (days <= 0) return 'Recuerdo de hoy';
  if (days == 1) return 'Recuerdo de hace 1 día';
  return 'Recuerdo de hace $days días';
}

int compareStoryRecency(Story a, Story b, {DateTime? now}) {
  return _ageMinutes(a, now: now).compareTo(_ageMinutes(b, now: now));
}

int _ageMinutes(Story story, {DateTime? now}) {
  final createdAt = story.createdAt;
  if (createdAt != null) {
    return (now ?? DateTime.now()).difference(createdAt).inMinutes;
  }
  final label = story.timeLabel.toLowerCase();
  final amount = int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '');
  if (amount == null) return 0;
  if (label.contains('día')) return amount * 24 * 60;
  if (label.contains(' h')) return amount * 60;
  return amount;
}
