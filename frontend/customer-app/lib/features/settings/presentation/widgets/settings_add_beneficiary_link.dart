import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsAddBeneficiaryLink extends StatelessWidget {
  const SettingsAddBeneficiaryLink({super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: callbackAction1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
          decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)),
          child:
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_add_alt_1_rounded,
                color: AppColors.primary, size: 18),
            SizedBox(width: AppSpacing.sm),
            Text('Thêm người thân mới',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
