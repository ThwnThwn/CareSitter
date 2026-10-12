import 'nutrition_error_codes.dart';

class NutritionResponseRules {
  static bool denied(int? statusCode) =>
      const [401, 403, 404].contains(statusCode);
  static bool stale(int? statusCode, String? code) =>
      statusCode == 409 &&
      const [
        NutritionErrorCodes.profileChanged,
        NutritionErrorCodes.contentChanged
      ].contains(code);
}
