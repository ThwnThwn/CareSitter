import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/api/api_constants.dart';

final gpsRepositoryProvider = Provider<GpsRepository>(
  (ref) => GpsRepository(ref.read(dioClientProvider)),
);

/// A single foreground sender owns one server-issued session per booking.
class GpsRepository {
  final DioClient _dio;
  const GpsRepository(this._dio);

  Future<Map<String, dynamic>> openSession(String bookingId, String sourceId,
      {ApiCancellation? cancelToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
        '${ApiPaths.postGps(bookingId)}/session',
        data: {'sourceInstanceId': sourceId},
        cancelToken: cancelToken?.transportToken);
    return response.data ?? {};
  }

  Future<String> bookingStatus(String bookingId,
      {ApiCancellation? cancelToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.booking(bookingId),
        cancelToken: cancelToken?.transportToken);
    return response.data?['status']?.toString() ?? '';
  }

  Future<void> postLocation(
    String bookingId, {
    required String sessionId,
    required DateTime capturedAt,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? speed,
    double? heading,
    ApiCancellation? cancelToken,
  }) async {
    await _dio.post<void>(
      ApiPaths.postGps(bookingId),
      cancelToken: cancelToken?.transportToken,
      data: {
        'sessionId': sessionId,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
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
