import 'package:uuid/uuid.dart';
import '../../data/repositories/booking_repository.dart';

class BookingPaymentController {
  BookingPaymentController(this.repository);
  final BookingRepository repository;
  final Map<String, String> _keys = {};
  Future<List<PaymentProviderModel>> providers() =>
      repository.getPaymentProviders();
  Future<PaymentIntentModel> create(String bookingId, String provider) =>
      repository.createPaymentIntent(bookingId, provider,
          idempotencyKey: _keys.putIfAbsent(
              '$bookingId:$provider', () => const Uuid().v4()));
  Future<PaymentIntentModel> get(String id) => repository.getPaymentIntent(id);
}
