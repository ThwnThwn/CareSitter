/// Keeps authenticated users out of auth pages and routes new sign-ins through
/// the brand reveal before opening the customer home.
String? authRouteRedirect({
  required String location,
  required bool isAuthenticated,
}) {
  final isAuthRoute = location.startsWith('/auth');
  final isBrandIntroRoute = location == '/brand-intro';

  if (!isAuthenticated && (!isAuthRoute || isBrandIntroRoute)) {
    return '/auth/login';
  }
  if (isAuthenticated && isAuthRoute) return '/brand-intro';
  return null;
}
