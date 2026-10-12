import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Cụm form nhập thông tin tài khoản ngân hàng nhận tiền.
class WithdrawalBankForm extends StatelessWidget {
  final TextEditingController bankNameController;
  final TextEditingController accountHolderController;
  final TextEditingController accountNumberController;

  const WithdrawalBankForm({
    super.key,
    required this.bankNameController,
    required this.accountHolderController,
    required this.accountNumberController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tài khoản nhận tiền',
          style: TextStyle(
            fontSize: AppFontSizes.s15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        TextFormField(
          controller: bankNameController,
          textInputAction: TextInputAction.next,
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Vui lòng nhập tên ngân hàng'
              : null,
          decoration: InputDecoration(
            labelText: 'Ngân hàng',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        TextFormField(
          controller: accountHolderController,
          textInputAction: TextInputAction.next,
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Vui lòng nhập tên chủ tài khoản'
              : null,
          decoration: InputDecoration(
            labelText: 'Tên chủ tài khoản',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        TextFormField(
          controller: accountNumberController,
          keyboardType: TextInputType.number,
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Vui lòng nhập số tài khoản'
              : null,
          decoration: InputDecoration(
            labelText: 'Số tài khoản',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ],
    );
  }
}
