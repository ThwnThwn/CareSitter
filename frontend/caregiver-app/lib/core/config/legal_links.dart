import 'package:url_launcher/url_launcher.dart';

abstract final class LegalLinks {
  static const _baseUrl = String.fromEnvironment('LEGAL_BASE_URL');

  static Uri? _resolve(String path) {
    final base = Uri.tryParse(_baseUrl.trim());
    if (base == null || !base.hasScheme || base.host.isEmpty) return null;
    return base.resolve(path.startsWith('/') ? path.substring(1) : path);
  }

  static Future<bool> openPrivacy() => _open('/privacy');
  static Future<bool> openTerms() => _open('/terms');
  static Future<bool> openAccountDeletion() => _open('/account-deletion');

  static Future<bool> _open(String path) async {
    final uri = _resolve(path);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
