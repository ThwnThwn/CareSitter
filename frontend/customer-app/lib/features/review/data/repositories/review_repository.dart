import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.read(dioClientProvider)),
);

class ReviewRepository {
  final DioClient _dio;
  const ReviewRepository(this._dio);

  /// Tạo đánh giá dịch vụ → POST /reviews
  Future<Map<String, dynamic>> createReview({
    required String bookingId,
    required String caregiverId,
    required int rating,
    String? comment,
    String? experienceTags,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.reviews,
      data: {
        'bookingId': bookingId,
        'caregiverId': caregiverId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (experienceTags != null && experienceTags.isNotEmpty)
          'experienceTags': experienceTags,
      },
    );
    return resp.data ?? {};
  }

  /// Tạo khiếu nại dịch vụ → POST /disputes
  Future<Map<String, dynamic>> createDispute({
    required String bookingId,
    required String reason,
    required String description,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.disputes,
      data: {
        'bookingId': bookingId,
        'reason': reason,
        'description': description,
      },
    );
    return resp.data ?? {};
  }

  /// Lấy danh sách reviews của một caregiver → GET /reviews/caregiver/{id}
  Future<Map<String, dynamic>> getCaregiverReviews(String caregiverId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      ApiPaths.caregiverReviews(caregiverId),
    );
    return resp.data ?? {};
  }

  /// Lấy danh sách disputes của user hiện tại → GET /disputes
  Future<List<dynamic>> getMyDisputes() async {
    final resp = await _dio.get<List<dynamic>>(
      ApiPaths.disputes,
    );
    return resp.data ?? [];
  }
}
