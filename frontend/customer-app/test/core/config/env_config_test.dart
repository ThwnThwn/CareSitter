import 'package:caresitter_customer/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google web login uses the versioned backend API route', () {
    const configured = String.fromEnvironment('GOOGLE_AUTH_BASE_URL');
    final input =
        configured.trim().isEmpty ? EnvConfig.apiBaseUrl : configured.trim();
    final base = Uri.parse(EnvConfig.googleAuthBaseUrl);
    expect(base.origin, Uri.parse(input).origin);
    expect(base.path, '/api/v1');
    expect(base.query, isEmpty);
    expect(base.fragment, isEmpty);
    expect(EnvConfig.googleAuthBaseUrl.endsWith('/'), isFalse);
  });
}
