import 'package:dio/dio.dart';

import 'package:caregiver_app/core/error/app_exception.dart';

enum FailureType {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  network,
  server,
  unknown
}

/// Dạng lỗi ổn định để controller và UI sử dụng, không phụ thuộc trực tiếp
/// vào cấu trúc lỗi của Dio hoặc backend.
class Failure {
  final String message;
  final FailureType type;
  final int? statusCode;
  final String? code;

  const Failure({
    required this.message,
    this.type = FailureType.unknown,
    this.statusCode,
    this.code,
  });

  factory Failure.from(Object error) {
    final appException = switch (error) {
      DioException(error: final AppException exception) => exception,
      AppException exception => exception,
      _ => null,
    };

    if (appException == null) {
      return const Failure(
        message: 'Đã xảy ra lỗi, vui lòng thử lại.',
      );
    }

    return Failure(
      message: appException.message,
      type: _typeForStatus(appException.statusCode),
      statusCode: appException.statusCode,
      code: appException.code,
    );
  }

  static FailureType _typeForStatus(int? statusCode) => switch (statusCode) {
        400 || 422 => FailureType.validation,
        401 => FailureType.unauthorized,
        403 => FailureType.forbidden,
        404 => FailureType.notFound,
        409 => FailureType.conflict,
        int value when value >= 500 => FailureType.server,
        null => FailureType.network,
        _ => FailureType.unknown,
      };
}

String apiErrorMessage(Object error) => Failure.from(error).message;
