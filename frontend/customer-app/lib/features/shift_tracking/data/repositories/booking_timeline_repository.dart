import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import '../models/booking_timeline_event_model.dart';

final bookingTimelineRepositoryProvider = Provider<BookingTimelineRepository>(
    (ref) => BookingTimelineRepository(ref.read(dioClientProvider)));

class BookingTimelineRepository {
  const BookingTimelineRepository(this._dio);
  final DioClient _dio;
  Future<List<BookingTimelineEventModel>> load(String bookingId) async {
    final response =
        await _dio.get<List<dynamic>>('/bookings/$bookingId/timeline');
    return response.data!
        .map((item) =>
            BookingTimelineEventModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
