import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/core/error/failure.dart';

void main() {
  test('maps API exceptions to a stable failure', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/bookings'),
      error: const AppApiException(
        message: 'Không tìm thấy ca làm.',
        statusCode: 404,
        code: 'BOOKING_NOT_FOUND',
      ),
    );

    final failure = Failure.from(error);

    expect(failure.type, FailureType.notFound);
    expect(failure.message, 'Không tìm thấy ca làm.');
    expect(failure.code, 'BOOKING_NOT_FOUND');
  });

  test('hides unknown technical errors behind a safe message', () {
    final failure = Failure.from(StateError('database details'));

    expect(failure.type, FailureType.unknown);
    expect(failure.message, 'Đã xảy ra lỗi, vui lòng thử lại.');
  });
}
