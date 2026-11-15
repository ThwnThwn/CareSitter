import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import '../models/booking_meals_model.dart';
import '../models/booking_meal_record_model.dart';

final bookingMealsRepositoryProvider = Provider<BookingMealsRepository>(
    (ref) => BookingMealsRepository(ref.read(dioClientProvider)));

class BookingMealsRepository {
  const BookingMealsRepository(this._dio);
  final DioClient _dio;

  Future<BookingMealsModel> load(String bookingId,
      {ApiCancellation? token}) async {
    final response = await _dio.get<Map<String, dynamic>>(
        '/bookings/$bookingId/meals',
        cancelToken: token?.transportToken);
    return BookingMealsModel.fromJson(response.data!);
  }

  Future<BookingMealRecordModel> record(String bookingId,
      {required String planId,
      required String recipeVersionId,
      required String mealType,
      required String outcome,
      required String idempotencyKey,
      String? note,
      ApiCancellation? token}) async {
    final response = await _dio.postIdempotent<Map<String, dynamic>>(
        '/bookings/$bookingId/meals/records',
        idempotencyKey: idempotencyKey,
        cancelToken: token?.transportToken,
        data: {
          'planId': planId,
          'recipeVersionId': recipeVersionId,
          'mealType': mealType,
          'outcome': outcome,
          'note': note
        });
    return BookingMealRecordModel.fromJson(response.data!);
  }

  Future<BookingMealRecordModel> correct(String bookingId,
      {required String recordId,
      required String outcome,
      required String reason,
      required int expectedRevision,
      required String idempotencyKey,
      String? note,
      ApiCancellation? token}) async {
    final response = await _dio.postIdempotent<Map<String, dynamic>>(
        '/bookings/$bookingId/meals/records/$recordId/corrections',
        idempotencyKey: idempotencyKey,
        cancelToken: token?.transportToken,
        data: {
          'outcome': outcome,
          'reason': reason,
          'note': note,
          'expectedRevision': expectedRevision
        });
    return BookingMealRecordModel.fromJson(response.data!);
  }
}
