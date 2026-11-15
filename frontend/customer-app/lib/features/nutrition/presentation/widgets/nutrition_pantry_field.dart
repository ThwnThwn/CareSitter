import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../domain/pantry_ingredients.dart';
import '../controllers/nutrition_pantry_controller.dart';

class NutritionPantryField extends ConsumerWidget {
  const NutritionPantryField(
      {super.key, required this.beneficiaryId, required this.enabled});
  final String beneficiaryId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(nutritionPantryProvider(beneficiaryId));
    final session = ref.watch(nutritionPantryProvider(beneficiaryId).notifier);
    final account = ref.watch(authStateProvider.select((state) =>
        (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.compact),
      child: TextFormField(
        key: ValueKey((beneficiaryId, account)),
        initialValue: value,
        enabled: enabled,
        maxLength: 1680,
        minLines: 1,
        maxLines: 3,
        onChanged: session.change,
        decoration: InputDecoration(
          labelText: 'Nguyên liệu đang có',
          hintText: 'Ví dụ: cá, bí đỏ, trứng',
          helperText:
              'Nhập có dấu, cách nhau bằng dấu phẩy. Chỉ ưu tiên khi tạo thực đơn mới; vẫn lọc theo hồ sơ.',
          helperMaxLines: 4,
          errorText: PantryIngredients.error(value),
          counterText: '',
        ),
      ),
    );
  }
}
