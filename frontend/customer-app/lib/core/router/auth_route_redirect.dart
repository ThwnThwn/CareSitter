/// Wait for persisted authentication before resolving an external return route.
Future<String?> authSessionRouteRedirect({
  required String location,
  required Future<bool> isAuthenticated,
}) async {
  bool authenticated;
  try {
    authenticated = await isAuthenticated;
  } catch (_) {
    authenticated = false;
  }
  return authRouteRedirect(
    location: location,
    isAuthenticated: authenticated,
  );
}

/// Preserve a payment return across a required sign-in without trusting its
/// query parameters as payment confirmation or allowing external redirects.
String? authRouteRedirect({
  required String location,
  required bool isAuthenticated,
}) {
  final uri = Uri.parse(location);
  final isAuthRoute = uri.path.startsWith('/auth');
  final isBrandIntroRoute = uri.path == '/brand-intro';

  if (!isAuthenticated && (!isAuthRoute || isBrandIntroRoute)) {
    if (_isPaymentReturn(uri)) {
      return Uri(path: '/auth/login', queryParameters: {
        'returnTo': uri.toString(),
      }).toString();
    }
    return '/auth/login';
  }
  if (isAuthenticated && isAuthRoute) {
    final returnTo = Uri.tryParse(uri.queryParameters['returnTo'] ?? '');
    if (returnTo != null && _isPaymentReturn(returnTo)) {
      return returnTo.toString();
    }
    return '/brand-intro';
  }
  return null;
}

bool _isPaymentReturn(Uri uri) =>
    !uri.hasScheme &&
    !uri.hasAuthority &&
    !uri.hasFragment &&
    uri.path == '/payment-result';
