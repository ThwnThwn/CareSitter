import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ActivityContent extends StatelessWidget {
  const ActivityContent({super.key});

  @override
  Widget build(BuildContext context) => SliverAppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        pinned: true,
        title: const Text(
          'Hoạt động',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/bookings'),
            icon: const Icon(Icons.history_rounded,
                color: AppColors.primary, size: 18),
            label: const Text(
              'Lịch sử',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSizes.s14,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl)),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
        ],
      );
}
