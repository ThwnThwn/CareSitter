String formatVnd(num amount,
    {String separator = '.',
    String suffix = 'đ',
    bool round = false,
    bool compact = false,
    String? zeroLabel}) {
  if (compact && amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}tr$suffix';
  }
  if (compact && amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}.000$suffix';
  }
  final value = round ? amount.round() : amount.toInt();
  if (value == 0 && zeroLabel != null) return zeroLabel;
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
    buffer.write(digits[i]);
  }
  return '$buffer$suffix';
}
