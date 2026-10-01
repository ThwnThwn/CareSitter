/// Cấu hình build-time dùng chung cho toàn ứng dụng.
abstract final class EnvConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5033/api/v1',
  );

  /// OAuth Web Client ID. The backend must validate this exact audience via
  /// `Google__ClientId`.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// OAuth iOS Client ID. Android and web do not use this value.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
}
