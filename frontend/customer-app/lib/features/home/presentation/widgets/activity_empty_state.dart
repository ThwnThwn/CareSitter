import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ActivityEmptyState extends StatelessWidget {
  const ActivityEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.track_changes_rounded,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Chưa có ca chăm sóc nào',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Đặt lịch ngay để bắt đầu theo dõi\nca chăm sóc cho người thân.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textHint, fontSize: AppFontSizes.s13),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => context.push('/booking/new'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Đặt lịch ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control)),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.wide, vertical: AppSpacing.inset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
