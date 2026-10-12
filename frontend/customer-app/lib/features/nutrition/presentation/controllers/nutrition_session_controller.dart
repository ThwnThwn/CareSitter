import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';

final nutritionSessionProvider =
    NotifierProvider<NutritionSession, int>(NutritionSession.new);

class NutritionSession extends Notifier<int> {
  @override
  int build() {
    ref.listen(authStateProvider, (old, next) {
      if (old?.value?.userId != next.value?.userId ||
          old?.value?.isAuthenticated != next.value?.isAuthenticated) {
        state++;
      }
    });
    return 0;
  }
}
