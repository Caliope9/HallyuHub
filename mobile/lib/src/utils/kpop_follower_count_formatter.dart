String formatSpanishInteger(int value) {
  final safeValue = value < 0 ? 0 : value;
  final digits = safeValue.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String formatKpopFollowerCount(int count) {
  final safeCount = count < 0 ? 0 : count;
  final label = safeCount == 1 ? 'seguidor' : 'seguidores';
  return '${formatSpanishInteger(safeCount)} $label';
}
