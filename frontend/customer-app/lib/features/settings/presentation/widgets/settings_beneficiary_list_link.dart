import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsBeneficiaryListLink extends StatelessWidget {
  const SettingsBeneficiaryListLink({super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: callbackAction1,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.inset),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 22)),
            const SizedBox(width: AppSpacing.compact),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Xem danh sách người thân',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s14,
                          fontWeight: FontWeight.w600)),
                  Text('Quản lý hồ sơ cần chăm sóc',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.s12)),
                ])),
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 20),
          ]),
        ),
      );
}
