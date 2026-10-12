import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingListScreenEmptyState extends StatelessWidget {
  const BookingListScreenEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Chưa có lịch hẹn',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Nhấn + để đặt lịch chăm sóc mới',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: AppFontSizes.s13),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => context.push('/booking/new'),
            icon: const Icon(Icons.add),
            label: const Text('Đặt lịch ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.compact),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ),
    );
  }
}
