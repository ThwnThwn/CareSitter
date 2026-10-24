import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final nutritionEntryPreferenceStoreProvider =
    Provider<NutritionEntryPreferenceStore>(
  (_) => _SharedPreferencesNutritionEntryPreferenceStore(),
);

abstract class NutritionEntryPreferenceStore {
  Future<String?> read(String userId);

  Future<void> write(String userId, String beneficiaryId);

  Future<void> clear(String userId);
}

class _SharedPreferencesNutritionEntryPreferenceStore
    implements NutritionEntryPreferenceStore {
  static const _keyPrefix = 'nutrition.last-beneficiary.';

  String _key(String userId) => '$_keyPrefix$userId';

  @override
  Future<String?> read(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key(userId));
  }

  @override
  Future<void> write(String userId, String beneficiaryId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(userId), beneficiaryId);
  }

  @override
  Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId));
  }
}
