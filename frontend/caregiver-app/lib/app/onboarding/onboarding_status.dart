import 'package:shared_preferences/shared_preferences.dart';

/// Chỉ lưu lựa chọn giao diện; token phiên vẫn thuộc secure storage của auth.
class OnboardingStatus {
  OnboardingStatus._();

  static const _key = 'onboarding_completed_v1';

  static Future<bool> hasCompleted() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, true);
  }
}
