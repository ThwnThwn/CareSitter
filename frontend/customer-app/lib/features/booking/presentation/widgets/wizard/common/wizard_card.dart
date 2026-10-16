import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class WizardCard extends StatelessWidget {
  const WizardCard(
      {super.key,
      required this.child,
      this.selected = false,
      this.highlightSelected = false,
      this.onTap});
  final Widget child;
  final bool selected;
  final bool highlightSelected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.control),
      child: Material(
          color: selected && highlightSelected
              ? AppColors.infoLight
              : AppColors.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 2 : 1)),
          elevation: 1,
          shadowColor: AppColors.shadow,
          child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.control),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.inset),
                  child: child))));
}
