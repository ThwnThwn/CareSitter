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
  final Map<String, dynamic>? details;
  final bool isCancelled;
  final int? retryAfterSeconds;
  bool get isTransportFailure => statusCode == null && !isCancelled;
  bool get outcomeMayBeUnknown =>
      statusCode == null ||
      (statusCode ?? 0) >= 500 ||
      (statusCode! >= 200 && statusCode! < 300);

  const AppApiException({
    required super.message,
    super.statusCode,
    super.code,
    this.details,
    this.isCancelled = false,
    this.retryAfterSeconds,
  });
}
