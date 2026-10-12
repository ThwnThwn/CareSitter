import 'package:caresitter_customer/features/booking/data/models/booking_list_response.dart';
import '../models/booking_draft.dart';
import '../models/payment_provider_model.dart';
import '../models/payment_intent_model.dart';
export '../models/booking_draft.dart';
export '../models/payment_provider_model.dart';
export '../models/payment_intent_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/realtime/gps_update.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_sync_model.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.read(dioClientProvider)),
);

/// Repository kết nối trực tiếp với backend API.
/// Mọi lỗi network được wrap bởi DioClient → _ErrorInterceptor → AppApiException.
class BookingRepository {
  final DioClient _dio;
  const BookingRepository(this._dio);

  /// Backend quyết định số tiền và tái sử dụng giao dịch đang mở của booking.
  Future<PaymentIntentModel> createPaymentIntent(String bookingId, String provider,
      {String? idempotencyKey}) async {
    final data = {'bookingId': bookingId, 'provider': provider};
    final resp = idempotencyKey == null
        ? await _dio.post<Map<String, dynamic>>(ApiPaths.paymentIntents, data: data)
        : await _dio.postIdempotent<Map<String, dynamic>>(ApiPaths.paymentIntents,
            data: data, idempotencyKey: idempotencyKey);
    return PaymentIntentModel.fromJson(resp.data ?? {});
  }

  Future<PaymentIntentModel> createVnPayIntent(String bookingId) =>
      createPaymentIntent(bookingId, 'VNPAY');

  Future<List<PaymentProviderModel>> getPaymentProviders() async {
    final response = await _dio.get<List<dynamic>>('/payments/providers');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PaymentProviderModel.fromJson)
        .toList();
  }

  Future<PaymentIntentModel> getPaymentIntent(String id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('${ApiPaths.paymentIntents}/$id');
    return PaymentIntentModel.fromJson(response.data ?? {});
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  /// Tạo booking mới từ BookingDraft.
  Future<BookingModel> createBooking(BookingDraft draft) async {
    final data = {
      'beneficiaryId': draft.beneficiaryId,
      'serviceTypeId': draft.serviceTypeId,
      'addressId': draft.addressId,
      'scheduledStart': draft.scheduledStart.toUtc().toIso8601String(),
      'scheduledEnd': draft.scheduledEnd.toUtc().toIso8601String(),
    };
    final resp = draft.idempotencyKey == null
        ? await _dio.post<Map<String, dynamic>>(ApiPaths.bookings, data: data)
        : await _dio.postIdempotent<Map<String, dynamic>>(ApiPaths.bookings,
            data: data, idempotencyKey: draft.idempotencyKey!);
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
    final serverTime = DateTime.tryParse(data['serverTime']?.toString() ?? '') ??
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

    final rawItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
    } on AppApiException catch (e) {
      // 404 = chưa có GPS track → return null
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Lifecycle mutations ──────────────────────────────────────────────────────

  /// Caregiver bắt đầu di chuyển → status: caregiver_en_route
  Future<BookingModel> startEnRoute(String bookingId) async {
    final resp = await _dio.post<Map<String, dynamic>>(ApiPaths.enRoute(bookingId));
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
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiPaths.checkoutRequest(bookingId));
    return BookingModel.fromJson(resp.data ?? {});
  }

  /// Customer xác nhận kết thúc ca → status: completed
  Future<BookingModel> completeBooking(String bookingId) async {
    final resp = await _dio.post<Map<String, dynamic>>(ApiPaths.complete(bookingId));
    return BookingModel.fromJson(resp.data ?? {});
  }

  /// Huỷ booking.
  Future<BookingModel> cancelBooking(String bookingId, {String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiPaths.bookingCancel(bookingId),
      // API yêu cầu JSON body kể cả khi không có lý do hủy.
      data: {'reason': reason},
    );
    return BookingModel.fromJson(response.data ?? {});
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
