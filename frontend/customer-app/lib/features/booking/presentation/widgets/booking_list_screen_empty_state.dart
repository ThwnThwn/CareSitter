import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import '../../domain/booking_status_rules.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingListScreenEmptyState extends StatelessWidget {
  const BookingListScreenEmptyState(
      {super.key, required this.category, required this.hasBookings});
  final BookingListCategory category;
  final bool hasBookings;

  @override
  Widget build(BuildContext context) {
    final title = switch (category) {
      BookingListCategory.active =>
        hasBookings ? 'Chưa có lịch đang xử lý' : 'Chưa có lịch hẹn',
      BookingListCategory.completed => 'Chưa có lịch hoàn tất',
      BookingListCategory.unmatched => 'Không có lịch cần ghép',
      BookingListCategory.disputed => 'Chưa có lịch khiếu nại',
      BookingListCategory.cancelled => 'Chưa có lịch hủy hoặc hoàn tiền',
    };
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w600),
          ),
          if (category == BookingListCategory.active && !hasBookings) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.bookingNew),
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
        ],
      ),
    );
  }
}
