/// Lỗi API đã được chuẩn hóa trước khi chuyển lên presentation layer.
class AppApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;

  const AppApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  @override
  String toString() => message;
}
