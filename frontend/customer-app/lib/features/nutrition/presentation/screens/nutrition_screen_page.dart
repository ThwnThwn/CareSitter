import 'package:flutter/material.dart';

import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_empty_state.dart';
import '../widgets/nutrition_menu_view.dart';
import '../widgets/nutrition_plan_loading.dart';
import '../widgets/nutrition_profile_editor.dart';
import '../widgets/nutrition_result.dart';
import '../widgets/nutrition_screen_app_bar.dart';
import 'nutrition_screen_page_actions.dart';
import 'nutrition_screen_page_state.dart';

class NutritionScreenPage extends StatelessWidget {
  const NutritionScreenPage({
    super.key,
    required this.state,
    required this.actions,
    required this.controller,
  });

  final NutritionScreenPageState state;
  final NutritionScreenPageActions actions;
  final NutritionFlowController controller;

  @override
  Widget build(BuildContext context) {
    final profileResult = state.flow.resource == null ||
            state.dirty ||
            !state.hasPlanForSelectedDate
        ? null
        : NutritionResult(
            flow: state.flow,
            controller: controller,
            plannedDate: state.selectedDate,
            onReplace: actions.onReplace,
          );
    final menuResult = NutritionResult(
      flow: state.flow,
      controller: controller,
      plannedDate: state.selectedDate,
      menuOnly: state.flow.resource?.status == 'saved',
      onReplace: actions.onReplace,
    );
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(profileResult, menuResult),
    );
  }

  PreferredSizeWidget _buildAppBar() => NutritionScreenAppBar(
        editing: state.editing,
        canReturnToMenu: state.canReturnToMenu,
        canReturnToBeneficiaries: state.canReturnToBeneficiaries,
        canEdit: state.canEdit,
        canOpenHistory: state.canOpenHistory,
        canChangeBeneficiary: state.canChangeBeneficiary,
        onReturnToMenu: actions.onReturnToMenu,
        onReturnToBeneficiaries: actions.onReturnToBeneficiaries,
        onEdit: actions.onEdit,
        onOpenHistory: actions.onOpenHistory,
        onChangeBeneficiary: actions.onChangeBeneficiary,
      );

  Widget _buildBody(Widget? profileResult, Widget menuResult) {
    final profile = state.health;
    if (profile == null) {
      return NutritionEmptyState(flow: state.flow, onReload: actions.onReload);
    }
    if (state.flow.restoringPlan) {
      return NutritionPlanLoading(name: state.beneficiaryName);
    }
    if (state.editing) {
      return NutritionProfileEditor(
        beneficiaryId: state.beneficiaryId,
        beneficiaryName: state.beneficiaryName,
        plannedDate: state.selectedDate,
        session: state.session,
        health: profile,
        flow: state.flow,
        dirty: state.dirty,
        onDirtyChanged: actions.onDirtyChanged,
        onSave: actions.onSave,
        onAssess: actions.onAssess,
        result: profileResult,
      );
    }
    return NutritionMenuView(
      beneficiaryName: state.beneficiaryName,
      flow: state.flow,
      selectedDate: state.selectedDate,
      hasPlanForSelectedDate: state.hasPlanForSelectedDate,
      isLoadingSelectedDate: state.isLoadingSelectedDate,
      dateError: state.dateError,
      onRetryDate: actions.onRetryDate,
      onCreatePlan: actions.onCreatePlan,
      onDateSelected: actions.onDateSelected,
      result: menuResult,
    );
  }
}
