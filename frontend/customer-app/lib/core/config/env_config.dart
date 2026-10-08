import 'package:flutter/services.dart';

/// Cấu hình dùng chung cho toàn ứng dụng.
///
/// Giá trị truyền qua `--dart-define` được ưu tiên. Nếu không có, app đọc
/// cấu hình public từ `.env` trước khi khởi động.
abstract final class EnvConfig {
  static Map<String, String> _fileValues = const {};

  static const _definedGoogleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const _definedGoogleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const _definedCartoApiKey = String.fromEnvironment('CARTO_API_KEY');
  static const _definedMapProvider = String.fromEnvironment('MAP_PROVIDER');

  static String get cartoApiKey => _resolve(
        key: 'CARTO_API_KEY',
        definedValue: _definedCartoApiKey,
      );

  /// CARTO mặc định; chỉ tải Google Maps khi chọn rõ ràng `google`.
  static String get mapProvider {
    final value = _resolve(
      key: 'MAP_PROVIDER',
      definedValue: _definedMapProvider,
    ).toLowerCase();
    return const {'carto', 'google', 'osm'}.contains(value) ? value : 'carto';
  }

  static Future<void> initialize({String fileName = '.env'}) async {
    final source = await rootBundle.loadString(fileName);
    _fileValues = _parse(source);
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
  static String get googleWebClientId => _resolve(
        key: 'GOOGLE_WEB_CLIENT_ID',
        definedValue: _definedGoogleWebClientId,
      );

  /// OAuth iOS Client ID. Android and web do not use this value.
  static String get googleIosClientId => _resolve(
        key: 'GOOGLE_IOS_CLIENT_ID',
        definedValue: _definedGoogleIosClientId,
      );

  static String _resolve({
    required String key,
    required String definedValue,
  }) {
    final override = definedValue.trim();
    if (override.isNotEmpty) return override;
    return _fileValues[key]?.trim() ?? '';
  }

  static Map<String, String> _parse(String source) {
    final values = <String, String>{};
    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final separator = line.indexOf('=');
      if (separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }
    return values;
  }
}
