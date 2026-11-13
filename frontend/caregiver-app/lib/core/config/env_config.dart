enum AppEnvironment { development, staging, production }

/// Cấu hình build-time của ứng dụng.
///
/// Ví dụ:
/// `flutter run --dart-define=APP_ENV=staging --dart-define=BASE_URL=https://.../api/v1`
abstract final class EnvConfig {
  /// Có thể truyền từ JSON hoặc .env qua `--dart-define-from-file`.
  static const _cartoApiKey = String.fromEnvironment('CARTO_API_KEY');
  static const _mapProvider =
      String.fromEnvironment('MAP_PROVIDER', defaultValue: 'carto');
  static String get cartoApiKey => _cartoApiKey.trim();
  static String get mapProvider => switch (_mapProvider.trim().toLowerCase()) {
        'osm' => 'osm',
        'osm_jp' => 'osm_jp',
        _ => 'carto',
      };
  static const String environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String _configuredBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5033/api/v1',
  );

  static String get baseUrl {
    if ((isProduction || const bool.fromEnvironment('dart.vm.product')) &&
        (_configuredBaseUrl.isEmpty ||
            _configuredBaseUrl.startsWith('http://localhost') ||
            _configuredBaseUrl.startsWith('http://127.0.0.1'))) {
      throw StateError('BASE_URL must be configured for production.');
    }
    return _configuredBaseUrl;
  }

  static AppEnvironment get environment => switch (environmentName) {
        'production' || 'prod' => AppEnvironment.production,
        'staging' || 'stage' => AppEnvironment.staging,
        _ => AppEnvironment.development,
      };

  static bool get isProduction => environment == AppEnvironment.production;
}
