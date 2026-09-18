/// Lỗi ứng dụng đã được chuẩn hóa trước khi chuyển lên presentation layer.
sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const AppException({
    required this.message,
    this.statusCode,
    this.code,
  });

  @override
  String toString() => '$runtimeType($statusCode, $code): $message';
}

final class AppApiException extends AppException {
  const AppApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}
