import 'app_routes.dart';

Future<String?> caregiverAuthRouteRedirect({
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

  final path = Uri.parse(location).path;
  if (path == AppRoutes.onboarding) {
    if (authenticated) return AppRoutes.home;
    return completedOnboarding ? AppRoutes.login : null;
  }

  final isAuthRoute = path.startsWith('/auth');
  if (!authenticated && !isAuthRoute) return AppRoutes.login;
  if (authenticated && isAuthRoute) return AppRoutes.home;
  return null;
}
