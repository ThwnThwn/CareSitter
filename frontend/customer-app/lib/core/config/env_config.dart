/// Cấu hình dùng chung cho toàn ứng dụng.
///
/// Mọi giá trị runtime được truyền qua `--dart-define` hoặc
/// `--dart-define-from-file=.env`. File `.env` không được đóng gói vào app.
abstract final class EnvConfig {
  static const _definedGoogleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const _definedGoogleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const _definedCartoApiKey = String.fromEnvironment('CARTO_API_KEY');
  static const _definedMapProvider = String.fromEnvironment('MAP_PROVIDER');

  static String get cartoApiKey => _definedCartoApiKey.trim();

  /// CARTO mặc định; chỉ tải Google Maps khi chọn rõ ràng `google`.
  static String get mapProvider {
    final value = _definedMapProvider.trim().toLowerCase();
    return const {'carto', 'google', 'osm'}.contains(value) ? value : 'carto';
  }

  static const apiBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5033/api/v1',
  );

  // Khóa dành cho ứng dụng khách; cấu hình bằng maps.local.json và giới hạn
  // theo package/SHA-1, bundle ID hoặc website trong Google Cloud.
  static const googleMapsAndroidApiKey =
      String.fromEnvironment('GOOGLE_MAPS_ANDROID_API_KEY');
  static const googleMapsIosApiKey =
      String.fromEnvironment('GOOGLE_MAPS_IOS_API_KEY');
  static const googleMapsWebApiKey =
      String.fromEnvironment('GOOGLE_MAPS_WEB_API_KEY');

  /// OAuth Web Client ID. The backend must validate this exact audience via
  /// `Google__ClientId`.
  static String get googleWebClientId => _definedGoogleWebClientId.trim();

  /// OAuth iOS Client ID. Android and web do not use this value.
  static String get googleIosClientId => _definedGoogleIosClientId.trim();
}
