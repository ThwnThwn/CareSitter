import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/data/models/payment_provider_model.dart';

class PaymentCheckoutSheetSelectedProviderInset extends StatelessWidget {
  const PaymentCheckoutSheetSelectedProviderInset(
      {super.key,
      required this.selected,
      required this.provider,
      required this.submitting,
      required this.callbackAction1});
  final String? selected;
  final PaymentProviderModel provider;
  final bool submitting;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.control),
        child: Semantics(
          selected: selected == provider.code,
          child: Material(
            color: selected == provider.code
                ? AppColors.successLight
                : AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: BorderSide(
                    color: selected == provider.code
                        ? AppColors.primary
                        : AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              enabled: provider.enabled && !submitting,
              onTap: provider.enabled && !submitting ? callbackAction1 : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              leading: Icon(
                  provider.code == 'PAYOS'
                      ? Icons.qr_code_rounded
                      : Icons.account_balance_outlined,
                  color: provider.enabled
                      ? AppColors.primary
                      : AppColors.textSecondary),
              title: Text(provider.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: provider.enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
              subtitle: Text(
                  provider.enabled ? provider.description : 'Hiện chưa khả dụng',
                  style: const TextStyle(color: AppColors.textSecondary)),
              trailing: Icon(
                  selected == provider.code
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: provider.enabled
                      ? AppColors.primary
                      : AppColors.textSecondary),
            ),
          ),
        ),
      );
}
