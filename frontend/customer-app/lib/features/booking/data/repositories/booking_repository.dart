import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:caresitter_customer/core/realtime/gps_update.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_sync_model.dart';

/// Dữ liệu cần thiết để tạo một booking mới.
class BookingDraft {
  final String beneficiaryId;
  final String serviceTypeId;
  final String? caregiverId;
  final bool isSystemMatched;
  final String addressId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  const BookingDraft({
    required this.beneficiaryId,
    required this.serviceTypeId,
    this.caregiverId,
    this.isSystemMatched = true,
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

  /// Tạo hoặc lấy lại PaymentIntent VNPay theo booking, không gửi amount từ app.
  Future<PaymentIntentModel> createVnPayIntent(String bookingId) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.paymentIntents,
      data: {'bookingId': bookingId},
    );
    return PaymentIntentModel.fromJson(resp.data ?? {});
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  /// Tạo booking mới từ BookingDraft.
  Future<BookingModel> createBooking(BookingDraft draft) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.bookings,
      data: {
        'beneficiaryId': draft.beneficiaryId,
        'serviceTypeId': draft.serviceTypeId,
        'addressId': draft.addressId,
        'scheduledStart': draft.scheduledStart.toUtc().toIso8601String(),
        'scheduledEnd': draft.scheduledEnd.toUtc().toIso8601String(),
      },
    );
    return BookingModel.fromJson(resp.data ?? {});
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  /// Lấy danh sách booking của customer hiện tại.
  /// Response bao gồm syncCursor để client dùng làm mốc bắt đầu delta sync.
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
    return BookingListResponse.fromJson(resp.data ?? {});
  }

  /// Delta sync: lấy danh sách booking thay đổi kể từ [cursor].
  /// Gọi sau khi nhận SignalR event, sau reconnect, hoặc theo polling 30s.
  /// Client merge result theo syncVersion (không ghi đè nếu đến cũ).
  Future<BookingSyncResponse> syncBookings(int cursor) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '${ApiPaths.bookings}/sync',
      query: {'cursor': cursor},
    );
    final data = resp.data ?? {};
    final resetRequired = data['resetRequired'] == true;
    final nextCursor = (data['nextCursor'] as num?)?.toInt() ?? cursor;
    final serverTime =
        DateTime.tryParse(data['serverTime']?.toString() ?? '') ??
            DateTime.now().toUtc();
    final hasMore = data['hasMore'] == true;

    if (resetRequired) {
      return BookingSyncResponse(
        items: const [],
        nextCursor: 0,
        serverTime: serverTime,
        hasMore: false,
        resetRequired: true,
      );
    }

    final rawItems =
        (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final items = rawItems.map(BookingModel.fromJson).toList();

    return BookingSyncResponse(
      items: items,
      nextCursor: nextCursor,
      serverTime: serverTime,
      hasMore: hasMore,
      resetRequired: false,
    );
  }

  /// Lấy chi tiết một booking theo ID.
  Future<BookingModel> getBooking(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>(ApiPaths.booking(id));
    return BookingModel.fromJson(resp.data ?? {});
  }

  /// Lấy danh sách nhiệm vụ chăm sóc (care tasks) của booking.
  Future<List<CareTaskModel>> getTasks(String bookingId) async {
    final resp = await _dio.get<List<dynamic>>(ApiPaths.tasks(bookingId));
    final list = resp.data ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CareTaskModel.fromApi)
        .toList();
  }

  /// Customer chọn thủ công một caregiver đã nằm trong danh sách gợi ý của booking.
  Future<BookingModel> selectCaregiver(
    String bookingId, {
    required String caregiverId,
  }) async {
    final resp = await _dio.put<Map<String, dynamic>>(
      ApiPaths.bookingCaregiver(bookingId),
      data: {'caregiverId': caregiverId},
    );
    return BookingModel.fromJson(resp.data ?? {});
  }

  /// Lấy vị trí GPS mới nhất của caregiver trong booking.
  /// Trả về null nếu chưa có GPS track nào (404).
  Future<GpsTrackModel?> getLatestGps(String bookingId) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>(ApiPaths.latestGps(bookingId));
      GpsUpdate.fromJson(
          resp.data ?? {}); // Validate the same contract as push events.
      return GpsTrackModel.fromJson(resp.data ?? {});
    } on DioException catch (e) {
      // 404 = chưa có GPS track → return null
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Lifecycle mutations ──────────────────────────────────────────────────────

  /// Caregiver bắt đầu di chuyển → status: caregiver_en_route
  Future<BookingModel> startEnRoute(String bookingId) async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.enRoute(bookingId));
    return BookingModel.fromJson(resp.data ?? {});
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
    return BookingModel.fromJson(resp.data ?? {});
  }

  /// Caregiver yêu cầu kết thúc ca → status: checkout_pending_review
  Future<BookingModel> requestCheckout(String bookingId) async {
    final resp = await _dio
        .post<Map<String, dynamic>>(ApiPaths.checkoutRequest(bookingId));
    return BookingModel.fromJson(resp.data ?? {});
  }

  /// Customer xác nhận kết thúc ca → status: completed
  Future<BookingModel> completeBooking(String bookingId) async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.complete(bookingId));
    return BookingModel.fromJson(resp.data ?? {});
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
    return GpsTrackModel.fromJson(resp.data ?? {});
  }
}

/// Dữ liệu URL và trạng thái thanh toán VNPay trả về cho customer app.
class PaymentIntentModel {
  final String id;
  final String status;
  final String paymentUrl;

  const PaymentIntentModel({
    required this.id,
    required this.status,
    required this.paymentUrl,
  });

  /// Parse response payment intent từ backend.
  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
    return PaymentIntentModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentUrl: json['paymentUrl']?.toString() ?? '',
    );
  }
}
