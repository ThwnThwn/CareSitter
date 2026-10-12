import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileBioSection extends StatelessWidget {
  const CaregiverProfileBioSection({super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        caregiver.bio != null && caregiver.bio!.isNotEmpty
            ? caregiver.bio!
            : 'Chăm sóc viên tận tâm, chu đáo, được đào tạo bài bản và luôn sẵn sàng hỗ trợ chăm sóc gia đình bạn.',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.s13,
          height: 1.5,
        ),
      ),
    );
  }
}
