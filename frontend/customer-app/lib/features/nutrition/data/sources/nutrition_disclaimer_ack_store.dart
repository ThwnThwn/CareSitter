import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final nutritionDisclaimerAckStoreProvider =
    Provider<NutritionDisclaimerAckStore>(
        (ref) => NutritionDisclaimerAckStore());

/// Stores only a confirmation flag, scoped to the account and disclaimer.
class NutritionDisclaimerAckStore {
  Future<bool> isAcknowledged(String userId, String version) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('nutrition_disclaimer_ack:$userId:$version') ??
        false;
  }

  Future<void> acknowledge(String userId, String version) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(
        'nutrition_disclaimer_ack:$userId:$version', true);
    if (!saved) throw StateError('Disclaimer acknowledgment was not saved');
  }
}
