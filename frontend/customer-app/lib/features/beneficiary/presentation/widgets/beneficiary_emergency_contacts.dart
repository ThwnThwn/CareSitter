import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryEmergencyContacts extends StatelessWidget {
  const BeneficiaryEmergencyContacts({super.key, required this.b});
  final BeneficiaryModel b;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.emergency_outlined,
                size: 18, color: AppColors.error),
          ),
          const SizedBox(width: AppSpacing.control),
          const Text(
            'Liên hệ khẩn cấp',
            style: TextStyle(
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.tiny),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              '${b.emergencyContacts.length} người',
              style: const TextStyle(
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      );
}
