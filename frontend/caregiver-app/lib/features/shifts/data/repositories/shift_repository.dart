import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/api/api_constants.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(ref.read(dioClientProvider)),
);

/// Repository kết nối các API ca làm việc (Shifts / Bookings) cho Caregiver.
class ShiftRepository {
  final DioClient _dio;
  const ShiftRepository(this._dio);

  /// Lấy danh sách ca làm việc của caregiver → GET /bookings
  Future<List<Map<String, dynamic>>> getShifts({
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      ApiPaths.bookings,
      query: {
        if (status != null) 'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final data = resp.data;
    if (data == null) return [];
    final items = data['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  /// Lấy các ca đã thanh toán nhưng chưa có caregiver nhận.
  ///
  /// Backend expose qua GET /bookings?status=open cho caregiver để phục vụ
  /// banner "ca mới phù hợp" và tab Đang chờ.
  Future<List<Map<String, dynamic>>> getOpenOffers({
    int page = 1,
    int pageSize = 20,
  }) =>
      getShifts(status: 'open', page: page, pageSize: pageSize);

  /// Chi tiết ca làm việc → GET /bookings/{id}
  Future<Map<String, dynamic>> getShift(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>(ApiPaths.booking(id));
    return resp.data ?? {};
  }

  /// Caregiver chấp nhận ca → POST /bookings/{id}/accept
  Future<Map<String, dynamic>> acceptBooking(String id) async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.acceptBooking(id));
    return resp.data ?? {};
  }

  /// Caregiver từ chối ca → POST /bookings/{id}/decline
  Future<void> declineBooking(String id, {String? reason}) async {
    await _dio.post<void>(
      ApiPaths.declineBooking(id),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()
      },
    );
  }

  /// Bắt đầu di chuyển → POST /bookings/{id}/en-route
  Future<Map<String, dynamic>> startEnRoute(String id) async {
    final resp = await _dio.post<Map<String, dynamic>>(ApiPaths.enRoute(id));
    return resp.data ?? {};
  }

  /// Check-in GPS → POST /bookings/{id}/check-in
  Future<Map<String, dynamic>> checkIn(
    String id, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.checkIn(id),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      },
    );
    return resp.data ?? {};
  }

  /// Upload ảnh selfie minh chứng trước khi gọi check-in GPS.
  Future<Map<String, dynamic>> uploadCheckInSelfie(
      String id, XFile image) async {
    final bytes = await image.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: image.name),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      ApiPaths.checkInSelfie(id),
      data: formData,
    );
    return response.data ?? {};
  }

  /// Yêu cầu checkout → POST /bookings/{id}/checkout/request
  Future<Map<String, dynamic>> requestCheckout(String id) async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.checkoutRequest(id));
    return resp.data ?? {};
  }

  /// Hoàn tất ca → POST /bookings/{id}/complete
  Future<Map<String, dynamic>> completeBooking(String id) async {
    final resp = await _dio.post<Map<String, dynamic>>(ApiPaths.complete(id));
    return resp.data ?? {};
  }

  Future<void> raiseSos(String id) async {
    await _dio.post<void>(ApiPaths.raiseSos(id));
  }

  Future<void> addTimelineNote(String id, String note) async {
    await _dio.post<void>(
      ApiPaths.timeline(id),
      data: {'title': 'Ghi chú cuối ca', 'note': note},
    );
  }

  Future<List<Map<String, dynamic>>> getTasks(String bookingId) async {
    final resp = await _dio.get<List<dynamic>>(ApiPaths.tasks(bookingId));
    return (resp.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> completeTask(
      String bookingId, String taskId) async {
    final resp = await _dio.patch<Map<String, dynamic>>(
      ApiPaths.taskComplete(bookingId, taskId),
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> uploadTaskPhoto(
      String bookingId, String taskId, XFile image) async {
    final mimeType = image.mimeType ?? _mimeTypeFor(image.name);
    final mimeParts = mimeType.split('/');
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        await image.readAsBytes(),
        filename: image.name,
        contentType: DioMediaType(
          mimeParts.first,
          mimeParts.length > 1 ? mimeParts[1] : 'octet-stream',
        ),
      ),
    });
    final resp = await _dio.postForm<Map<String, dynamic>>(
      ApiPaths.taskPhotos(bookingId, taskId),
      formData,
    );
    return resp.data ?? {};
  }

  String _mimeTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<Map<String, dynamic>> skipTask(
      String bookingId, String taskId, String skipReason) async {
    final resp = await _dio.patch<Map<String, dynamic>>(
      ApiPaths.taskSkip(bookingId, taskId),
      data: {'skipReason': skipReason},
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> createTask(String bookingId, String name,
      {String? description}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.tasks(bookingId),
      data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return resp.data ?? {};
  }
}
