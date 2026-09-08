import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/api/api_constants.dart';
import 'models/booking_model.dart';

/// Dữ liệu cần thiết để tạo một booking mới.
class BookingDraft {
  final String beneficiaryId;
  final String serviceTypeId;
  final String? caregiverId;
  final String addressId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  const BookingDraft({
    required this.beneficiaryId,
    required this.serviceTypeId,
    this.caregiverId,
    required this.addressId,
    required this.scheduledStart,
    required this.scheduledEnd,
  });
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.read(dioClientProvider)),
);

/// Repository kết nối trực tiếp với backend API.
/// Mọi lỗi network được wrap bởi DioClient → _ErrorInterceptor → AppApiException.
class BookingRepository {
  final DioClient _dio;
  const BookingRepository(this._dio);

  // ── Mutations ────────────────────────────────────────────────────────────────

  /// Tạo booking mới từ BookingDraft.
  Future<BookingModel> createBooking(BookingDraft draft) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.bookings,
      data: {
        'beneficiaryId': draft.beneficiaryId,
        'serviceTypeId': draft.serviceTypeId,
        if (draft.caregiverId != null) 'caregiverId': draft.caregiverId,
        'addressId': draft.addressId,
        'scheduledStart': draft.scheduledStart.toUtc().toIso8601String(),
        'scheduledEnd': draft.scheduledEnd.toUtc().toIso8601String(),
      },
    );
    return BookingModel.fromJson(resp.data!);
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  /// Lấy danh sách booking của customer hiện tại.
  /// [status] có thể là: pending_payment | confirmed | caregiver_accepted |
  ///                     caregiver_en_route | in_progress |
  ///                     checkout_pending_review | completed | cancelled | disputed
  Future<BookingListResponse> getBookings({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      ApiPaths.bookings,
      query: {
        if (status != null) 'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return BookingListResponse.fromJson(resp.data!);
  }

  /// Lấy chi tiết một booking theo ID.
  Future<BookingModel> getBooking(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>(ApiPaths.booking(id));
    return BookingModel.fromJson(resp.data!);
  }

  /// Lấy vị trí GPS mới nhất của caregiver trong booking.
  /// Trả về null nếu chưa có GPS track nào (404).
  Future<GpsTrackModel?> getLatestGps(String bookingId) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>(ApiPaths.latestGps(bookingId));
      return GpsTrackModel.fromJson(resp.data!);
    } on Exception catch (e) {
      // 404 = chưa có GPS track → return null
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  // ── Lifecycle mutations ──────────────────────────────────────────────────────

  /// Xác nhận thanh toán ký quỹ (escrow) → status: confirmed
  Future<BookingModel> confirmPayment(String bookingId) async {
    final resp = await _dio
        .post<Map<String, dynamic>>(ApiPaths.confirmPayment(bookingId));
    return BookingModel.fromJson(resp.data!);
  }

  /// Caregiver bắt đầu di chuyển → status: caregiver_en_route
  Future<BookingModel> startEnRoute(String bookingId) async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.enRoute(bookingId));
    return BookingModel.fromJson(resp.data!);
  }

  /// Caregiver GPS check-in tại địa điểm → status: in_progress
  Future<BookingModel> checkIn(
    String bookingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.checkIn(bookingId),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      },
    );
    return BookingModel.fromJson(resp.data!);
  }

  /// Caregiver yêu cầu kết thúc ca → status: checkout_pending_review
  Future<BookingModel> requestCheckout(String bookingId) async {
    final resp = await _dio
        .post<Map<String, dynamic>>(ApiPaths.checkoutRequest(bookingId));
    return BookingModel.fromJson(resp.data!);
  }

  /// Customer xác nhận kết thúc ca → status: completed
  Future<BookingModel> completeBooking(String bookingId) async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.complete(bookingId));
    return BookingModel.fromJson(resp.data!);
  }

  /// Huỷ booking.
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    await _dio.post<void>(
      ApiPaths.bookingCancel(bookingId),
      data: reason != null ? {'reason': reason} : null,
    );
  }

  // ── GPS push (Caregiver) ─────────────────────────────────────────────────────

  /// Caregiver gửi vị trí GPS hiện tại lên server.
  Future<GpsTrackModel> postGps(
    String bookingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? speed,
    double? heading,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.postGps(bookingId),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
      },
    );
    return GpsTrackModel.fromJson(resp.data!);
  }
}
