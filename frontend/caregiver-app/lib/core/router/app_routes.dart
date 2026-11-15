/// Public paths used by the caregiver onboarding flow.
class AppRoutes {
  AppRoutes._();

  static const home = '/home';
  static const onboarding = '/onboarding';
  static const login = '/auth/phone';
  static const register = '/auth/register';
  static String shiftDetail(String id) => '/shifts/${Uri.encodeComponent(id)}';
  static String shiftMeals(String id) => '${shiftDetail(id)}/meals';
}
