import 'package:flutter/material.dart';

import '../../data/models/health_profile_model.dart';
import '../models/nutrition_flow_model.dart';

class NutritionScreenPageState {
  const NutritionScreenPageState({
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.session,
    required this.flow,
    required this.health,
    required this.editing,
    required this.dirty,
    required this.selectedDate,
    required this.hasPlanForSelectedDate,
    required this.isLoadingSelectedDate,
    required this.dateError,
    required this.canReturnToMenu,
    required this.canReturnToBeneficiaries,
    required this.canEdit,
    required this.canOpenHistory,
    required this.canChangeBeneficiary,
  });

  factory NutritionScreenPageState.fromFlow({
    required String beneficiaryId,
    required String? beneficiaryName,
    required int session,
    required NutritionFlow flow,
    required DateTime selectedDate,
    required bool dirty,
    required bool editingProfile,
    required bool historyLoading,
    required bool canChangeBeneficiary,
  }) {
    final health = flow.health;
    final resourceDate = DateTime.tryParse(
      flow.resource?.result.plannedDate ?? '',
    );
    final hasPlanForSelectedDate = flow.resource != null &&
        (resourceDate == null ||
            DateUtils.isSameDay(resourceDate, selectedDate));
    final dateError =
        flow.dateError ?? (!hasPlanForSelectedDate ? flow.error : null);
    final editing = !flow.restoringPlan && (editingProfile || health == null);
    return NutritionScreenPageState(
      beneficiaryId: beneficiaryId,
      beneficiaryName: beneficiaryName,
      session: session,
      flow: flow,
      health: health,
      editing: editing,
      dirty: dirty,
      selectedDate: selectedDate,
      hasPlanForSelectedDate: hasPlanForSelectedDate,
      isLoadingSelectedDate: flow.dateLoading,
      dateError: dateError,
      canReturnToMenu:
          editingProfile && health != null && !dirty && !flow.loading,
      canReturnToBeneficiaries: canChangeBeneficiary && !dirty && !flow.loading,
      canEdit: health != null && !editingProfile && !flow.loading,
      canOpenHistory: health != null &&
          !dirty &&
          !flow.loading &&
          !historyLoading &&
          !flow.dateLoading,
      canChangeBeneficiary: canChangeBeneficiary && !dirty && !flow.loading,
    );
  }

  final String beneficiaryId;
  final String? beneficiaryName;
  final int session;
  final NutritionFlow flow;
  final HealthProfileModel? health;
  final bool editing;
  final bool dirty;
  final DateTime selectedDate;
  final bool hasPlanForSelectedDate;
  final bool isLoadingSelectedDate;
  final String? dateError;
  final bool canReturnToMenu;
  final bool canReturnToBeneficiaries;
  final bool canEdit;
  final bool canOpenHistory;
  final bool canChangeBeneficiary;
}
