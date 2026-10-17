import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/earnings/domain/supported_bank.dart';

/// Cụm form nhập thông tin tài khoản ngân hàng nhận tiền.
class WithdrawalBankForm extends StatelessWidget {
  final SupportedBank? selectedBank;
  final ValueChanged<SupportedBank?> onBankChanged;
  final TextEditingController accountHolderController;
  final TextEditingController accountNumberController;

  const WithdrawalBankForm({
    super.key,
    required this.selectedBank,
    required this.onBankChanged,
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
        DropdownButtonFormField<SupportedBank>(
          initialValue: selectedBank,
          isExpanded: true,
          menuMaxHeight: 360,
          decoration: const InputDecoration(
            labelText: 'Ngân hàng',
            hintText: 'Chọn ngân hàng nhận tiền',
          ),
          items: supportedPayoutBanks
              .map((bank) => DropdownMenuItem(
                    value: bank,
                    child: Text(bank.label, overflow: TextOverflow.ellipsis),
                  ))
              .toList(growable: false),
          onChanged: onBankChanged,
          validator: (bank) => bank == null ? 'Vui lòng chọn ngân hàng' : null,
        ),
        const SizedBox(height: AppSpacing.compact),
        TextFormField(
          controller: accountHolderController,
          textInputAction: TextInputAction.next,
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Vui lòng nhập tên chủ tài khoản'
              : null,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Tên chủ tài khoản',
            hintText: 'Đúng như trên tài khoản ngân hàng',
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        TextFormField(
          controller: accountNumberController,
          keyboardType: TextInputType.number,
          validator: (val) {
            final value = val?.trim() ?? '';
            if (value.isEmpty) return 'Vui lòng nhập số tài khoản';
            if (!RegExp(r'^\d{4,50}$').hasMatch(value)) {
              return 'Số tài khoản chỉ gồm chữ số';
            }
            return null;
          },
          decoration: const InputDecoration(
            labelText: 'Số tài khoản',
            hintText: 'Không nhập số thẻ',
          ),
        ),
      ],
    );
  }
}
