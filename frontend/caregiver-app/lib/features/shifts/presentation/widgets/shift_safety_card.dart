import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'shift_safety_content.dart';

class ShiftSafetyCard extends StatefulWidget {
  const ShiftSafetyCard({super.key});
  @override
  State<ShiftSafetyCard> createState() => _ShiftSafetyCardState();
}

class _ShiftSafetyCardState extends State<ShiftSafetyCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border)),
        child: ShiftSafetyContent(
            safetyExpanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded)),
      );
}
