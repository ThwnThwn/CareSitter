import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class HomeOfferDisplayModel {
  const HomeOfferDisplayModel._();

  static String? countdownLabel(Duration? remaining) {
    if (remaining == null || remaining <= Duration.zero) return null;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return 'Còn $minutes:$seconds';
  }

  static String locationLabel(ShiftModel booking) {
    final address = booking.address.trim();
    if (address.isEmpty || address == 'Địa chỉ khách hàng đã đăng ký') {
      return 'Địa chỉ theo booking';
    }
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.length >= 2 ? parts.take(2).join(', ') : address;
  }
}
