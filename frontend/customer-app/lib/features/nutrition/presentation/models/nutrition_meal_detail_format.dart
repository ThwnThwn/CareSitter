String nutritionDisplayValue(Object? value) {
  if (value is num) return nutritionDisplayNumber(value);
  return value?.toString() ?? '—';
}

String nutritionDisplayNumber(num value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
