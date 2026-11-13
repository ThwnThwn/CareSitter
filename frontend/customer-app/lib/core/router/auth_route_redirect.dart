import 'app_routes.dart';

/// Wait for persisted authentication before resolving an external return route.
Future<String?> authSessionRouteRedirect({
  required String location,
  required Future<bool> isAuthenticated,
  Future<bool>? hasCompletedOnboarding,
}) async {
  bool authenticated;
  try {
    authenticated = await isAuthenticated;
  } catch (_) {
    authenticated = false;
  }
  bool completedOnboarding = true;
  if (hasCompletedOnboarding != null) {
    try {
      completedOnboarding = await hasCompletedOnboarding;
    } catch (_) {
      completedOnboarding = false;
    }
  }
  return authRouteRedirect(
    location: location,
    isAuthenticated: authenticated,
    hasCompletedOnboarding: completedOnboarding,
  );
}

/// Preserve a payment return across a required sign-in without trusting its
/// query parameters as payment confirmation or allowing external redirects.
String? authRouteRedirect({
  required String location,
  required bool isAuthenticated,
  bool hasCompletedOnboarding = true,
}) {
  final uri = Uri.parse(location);
  final isAuthRoute = uri.path.startsWith(AppRoutes.auth);
  final isBrandIntroRoute = uri.path == AppRoutes.brandIntro;

  if (uri.path == AppRoutes.onboarding) {
    if (isAuthenticated) return AppRoutes.home;
    return hasCompletedOnboarding ? AppRoutes.login : null;
  }

  if (!isAuthenticated && (!isAuthRoute || isBrandIntroRoute)) {
    if (_isAllowedReturn(uri)) {
      return Uri(path: AppRoutes.login, queryParameters: {
        'return-to': uri.toString(),
      }).toString();
    }
    return AppRoutes.login;
  }
  if (isAuthenticated && isAuthRoute) {
    final returnTo = Uri.tryParse(
      uri.queryParameters['return-to'] ?? uri.queryParameters['returnTo'] ?? '',
    );
    if (returnTo != null && _isAllowedReturn(returnTo)) {
      return returnTo.toString();
    }
    return AppRoutes.brandIntro;
  }
  return null;
}

bool _isPaymentReturn(Uri uri) =>
    !uri.hasScheme &&
    !uri.hasAuthority &&
    !uri.hasFragment &&
    uri.path == AppRoutes.paymentResult;

bool _isAllowedReturn(Uri uri) =>
    _isPaymentReturn(uri) ||
    (!uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasFragment &&
        !uri.hasQuery &&
        RegExp(r'^/bookings/[a-zA-Z0-9-]+/reports$').hasMatch(uri.path));
