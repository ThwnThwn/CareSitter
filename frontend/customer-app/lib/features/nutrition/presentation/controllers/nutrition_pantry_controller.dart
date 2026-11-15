import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';

final nutritionPantryProvider = AutoDisposeNotifierProvider.family<
    NutritionPantryController, String, String>(NutritionPantryController.new);

class NutritionPantryController
    extends AutoDisposeFamilyNotifier<String, String> {
  @override
  String build(String arg) {
    ref.watch(authStateProvider.select((state) =>
        (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
    return '';
  }

  void change(String value) => state = value;
}
