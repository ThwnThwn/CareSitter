import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class WithdrawalUseBalanceAction extends StatelessWidget {
  const WithdrawalUseBalanceAction(
      {super.key,
      required this.amountController,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController amountController;
  final String? Function(String?) callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: amountController,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontSize: AppFontSizes.s24,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        validator: callbackAction1,
        decoration: InputDecoration(
          prefixText: 'đ ',
          prefixStyle: const TextStyle(
            fontSize: AppFontSizes.s20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          hintText: '0',
          suffixIcon: TextButton(
            onPressed: callbackAction2,
            child: const Text(
              'Rút hết',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.section,
            vertical: AppSpacing.md,
          ),
        ),
      );
}
