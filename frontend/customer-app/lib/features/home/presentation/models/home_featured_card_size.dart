import 'dart:ui';

Size homeFeaturedCardSize(double textScale) {
  final extraSize = (textScale.clamp(1.0, 1.3).toDouble() - 1) * 32;
  return Size(156 + extraSize, 168 + extraSize);
}
