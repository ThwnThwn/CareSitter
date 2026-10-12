/// Lỗi API đã được chuẩn hóa trước khi chuyển lên presentation layer.
class AppApiException implements Exception {
  final bool isCancelled;
  final int? retryAfterSeconds;
  bool get isTransportFailure => statusCode == null && !isCancelled;
  bool get outcomeMayBeUnknown =>
      statusCode == null ||
      (statusCode ?? 0) >= 500 ||
      (statusCode! >= 200 && statusCode! < 300);
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;

  const AppApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
    this.isCancelled = false,
    this.retryAfterSeconds,
  });

  @override
  String toString() => message;
}
