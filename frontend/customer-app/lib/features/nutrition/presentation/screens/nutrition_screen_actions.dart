import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../controllers/nutrition_controller.dart';
import '../../data/models/recipe_option_model.dart';

class NutritionScreenActions {
  const NutritionScreenActions._();

  static void saveHealth(
    BuildContext context,
    NutritionFlowController controller,
    Map<String, dynamic> changes,
  ) {
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có thông tin thay đổi.')),
      );
      return;
    }
    controller.saveHealth(changes);
  }

  static Future<void> replaceMeal({
    required BuildContext context,
    required NutritionFlowController controller,
    required String mealType,
    required bool Function() isCurrent,
    required ValueChanged<VoidCallback?> onCloseSheetChanged,
  }) async {
    final options = await controller.options(mealType);
    if (!context.mounted || !isCurrent() || options == null) return;

    final chosen = await showSheet<String>(
      context: context,
      onCloseSheetChanged: onCloseSheetChanged,
      builder: (_) => _ReplacementOptionsSheet(options: options),
    );
    if (isCurrent() && chosen != null) {
      await controller.replace(chosen, mealType);
    }
  }

  static Future<T?> showSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    required ValueChanged<VoidCallback?> onCloseSheetChanged,
  }) async {
    try {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          onCloseSheetChanged(() {
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          });
          return builder(sheetContext);
        },
      );
    } finally {
      onCloseSheetChanged(null);
    }
  }
}

class _ReplacementOptionsSheet extends StatelessWidget {
  const _ReplacementOptionsSheet({required this.options});

  final List<RecipeOptionModel> options;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: options.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Chưa có món thay thế đáp ứng các yêu cầu của thực đơn.',
                    ),
                  ),
                )
              : ListView(
                  children: [
                    const ListTile(title: Text('Món thay thế phù hợp')),
                    for (final recipe in options)
                      ListTile(
                        title: Text(recipe.name),
                        subtitle: Text('Khẩu phần: ${recipe.servings} phần'),
                        onTap: () => Navigator.pop(context, recipe.versionId),
                      ),
                  ],
                ),
        ),
      );
}
