import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import '../models/booking_meals_model.dart';
import '../models/booking_meal_plan_model.dart';

final bookingMealsRepositoryProvider = Provider<BookingMealsRepository>(
    (ref) => BookingMealsRepository(ref.read(dioClientProvider)));

class BookingMealsRepository {
  const BookingMealsRepository(this._dio);
  final DioClient _dio;
  Future<BookingMealsModel> load(
      String bookingId, ApiCancellation token) async {
    final response = await _dio.getCancelable<Map<String, dynamic>>(
        '/bookings/$bookingId/meals',
        cancelToken: token.transportToken);
    return BookingMealsModel.fromJson(response.data!);
  }

  Future<BookingMealPlanModel> share(
      String bookingId, String planId, ApiCancellation token) async {
    final response = await _dio.putCancelable<Map<String, dynamic>>(
        '/bookings/$bookingId/meals/plan',
        data: {'planId': planId},
        cancelToken: token.transportToken);
    return BookingMealPlanModel.fromJson(response.data!);
  }

  Future<void> revoke(
          String bookingId, String plannedDate, ApiCancellation token) =>
      _dio.deleteCancelable<dynamic>(
          '/bookings/$bookingId/meals/plan/$plannedDate',
          cancelToken: token.transportToken);
}
