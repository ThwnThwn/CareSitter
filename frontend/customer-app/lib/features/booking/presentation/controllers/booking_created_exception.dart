import '../../data/models/booking_model.dart';

class BookingCreatedException implements Exception {
  final BookingModel booking;
  const BookingCreatedException(this.booking);
}
