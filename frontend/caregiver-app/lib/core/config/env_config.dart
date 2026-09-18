enum AppEnvironment { development, staging, production }

/// Cấu hình build-time của ứng dụng.
///
/// Ví dụ:
/// `flutter run --dart-define=APP_ENV=staging --dart-define=BASE_URL=https://.../api/v1`
abstract final class EnvConfig {
  static const String environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5033/api/v1',
  );

  static AppEnvironment get environment => switch (environmentName) {
        'production' || 'prod' => AppEnvironment.production,
        'staging' || 'stage' => AppEnvironment.staging,
        _ => AppEnvironment.development,
      };

  static bool get isProduction => environment == AppEnvironment.production;
}
