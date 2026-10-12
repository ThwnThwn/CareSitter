/// Chuyển status về lower_snake_case thống nhất.
/// BE có thể trả UPPER_SNAKE (dữ liệu cũ/cache) hoặc lower_snake (mới).
/// Hàm này đảm bảo FE luôn nhận lower_snake_case.
String normalizeBookingStatus(String raw) {
  var value = raw.trim().replaceAll('-', '_');
  value = value.replaceAllMapped(
    RegExp(r'([A-Z]+)([A-Z][a-z])'),
    (m) => '${m.group(1)}_${m.group(2)}',
  );
  value = value.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m.group(1)}_${m.group(2)}',
  );
  value = value.toLowerCase();

  return switch (value) {
    'en_route' => 'caregiver_en_route',
    'assigned' => 'caregiver_accepted',
    'checkout_requested' => 'checkout_pending_review',
    'payment_confirmed' => 'confirmed',
    _ => value,
  };
}
