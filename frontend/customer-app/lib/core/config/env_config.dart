/// Cấu hình build-time dùng chung cho toàn ứng dụng.
abstract final class EnvConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5033/api/v1',
  );
}
