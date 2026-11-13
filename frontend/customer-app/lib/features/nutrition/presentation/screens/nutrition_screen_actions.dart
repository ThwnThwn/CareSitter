import '../widgets/nutrition_plan_history_sheet.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';

import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_plan_setup_sheet.dart';
import '../widgets/nutrition_replacement_sheet.dart';

class NutritionScreenActions {
  const NutritionScreenActions._();

  static Future<int?> choosePlanDays({
    required BuildContext context,
    required DateTime startDate,
    required String? beneficiaryName,
    required ValueChanged<VoidCallback?> onCloseSheetChanged,
  }) =>
      showSheet<int>(
        context: context,
        onCloseSheetChanged: onCloseSheetChanged,
        builder: (_) => NutritionPlanSetupSheet(
          startDate: startDate,
          beneficiaryName: beneficiaryName,
        ),
      );

  static Future<void> createWeek({
    required BuildContext context,
    required NutritionFlowController controller,
    required DateTime selectedDate,
    required int days,
    required bool Function() isCurrent,
    required VoidCallback onNeedsProfile,
    bool confirmFirst = false,
  }) async {
    if (confirmFirst) {
      await controller.confirm();
      if (!context.mounted || !isCurrent()) {
        return;
      }
      final confirmed = controller.view.resource;
      if (controller.view.error != null ||
          confirmed?.status != 'confirmed' ||
          confirmed?.result.decision.allows('recommend') != true) {
        return;
      }
      AppToast.success(context, 'Lưu thông tin thành công');
    }
    final result = await controller.generateWeek(selectedDate, days: days);
    if (!context.mounted || !isCurrent()) {
      return;
    }
    if (result.needsProfile) {
      onNeedsProfile();
      AppToast.error(context, result.error!);
      return;
    }
    if (result.completed) {
      AppToast.success(
          context,
          result.createdDays == 0
              ? 'Đã có thực đơn cho đủ $days ngày'
              : 'Đã lưu thực đơn cho đủ $days ngày');
    } else {
      AppToast.error(context,
          '${result.error ?? 'Chưa hoàn tất kế hoạch.'} Đã có ${result.createdDays + result.existingDays}/$days ngày.');
    }
  }

  static Future<bool> openHistory({
    required BuildContext context,
    required NutritionFlowController controller,
    required bool Function() isCurrent,
    required ValueChanged<VoidCallback?> onCloseSheetChanged,
  }) async {
    final plans = await controller.plans();
    if (!context.mounted || !isCurrent() || plans == null) return false;
    final chosen = await showSheet<String>(
      context: context,
      onCloseSheetChanged: onCloseSheetChanged,
      builder: (_) => NutritionPlanHistorySheet(plans: plans),
    );
    if (!context.mounted || !isCurrent() || chosen == null) return false;
    await controller.openPlan(chosen);
    if (!context.mounted || !isCurrent()) return false;
    final openedResource = controller.view.resource;
    final plannedDate = openedResource?.id == chosen
        ? DateTime.tryParse(openedResource!.result.plannedDate ?? '')
        : null;
    if (plannedDate != null) controller.adoptResourceDate();
    return true;
  }

  static void saveHealth(
    BuildContext context,
    NutritionFlowController controller,
    Map<String, dynamic> changes,
  ) {
    if (changes.isEmpty) {
      AppToast.showLegacy(
        context,
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
      builder: (_) => NutritionReplacementSheet(options: options),
    );
    if (context.mounted && isCurrent() && chosen != null) {
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
