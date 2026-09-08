import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/api/api_constants.dart';

final gpsRepositoryProvider = Provider<GpsRepository>(
  (ref) => GpsRepository(ref.read(dioClientProvider)),
);

/// Push vị trí GPS của caregiver lên backend.
class GpsRepository {
  final DioClient _dio;
  const GpsRepository(this._dio);

  /// Gửi tọa độ GPS hiện tại → POST /bookings/{id}/gps
  Future<void> postLocation(
    String bookingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? speed,
    double? heading,
  }) async {
    await _dio.post<void>(
      ApiPaths.postGps(bookingId),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
      },
    );
  }

  /// Bắt đầu di chuyển → POST /bookings/{id}/en-route
  Future<void> startEnRoute(String bookingId) async {
    await _dio.post<void>(ApiPaths.enRoute(bookingId));
  }

  /// GPS check-in tại địa điểm → POST /bookings/{id}/check-in
  Future<void> checkIn(
    String bookingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    await _dio.post<void>(
      ApiPaths.checkIn(bookingId),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      },
    );
  }

  /// Yêu cầu kết thúc ca → POST /bookings/{id}/checkout/request
  Future<void> requestCheckout(String bookingId) async {
    await _dio.post<void>(ApiPaths.checkoutRequest(bookingId));
  }
}
