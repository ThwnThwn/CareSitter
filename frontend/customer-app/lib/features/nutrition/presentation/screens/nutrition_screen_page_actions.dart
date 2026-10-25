import 'package:flutter/material.dart';

class NutritionScreenPageActions {
  const NutritionScreenPageActions({
    required this.onReturnToMenu,
    required this.onReturnToBeneficiaries,
    required this.onEdit,
    required this.onOpenHistory,
    required this.onChangeBeneficiary,
    required this.onReload,
    required this.onDirtyChanged,
    required this.onSave,
    required this.onAssess,
    required this.onReplace,
    required this.onDateSelected,
    required this.onRetryDate,
    required this.onEditProfile,
  });

  final VoidCallback onReturnToMenu;
  final VoidCallback onReturnToBeneficiaries;
  final VoidCallback onEdit;
  final VoidCallback onOpenHistory;
  final VoidCallback onChangeBeneficiary;
  final VoidCallback onReload;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onAssess;
  final ValueChanged<String> onReplace;
  final ValueChanged<DateTime>? onDateSelected;
  final VoidCallback? onRetryDate;
  final VoidCallback onEditProfile;
}
