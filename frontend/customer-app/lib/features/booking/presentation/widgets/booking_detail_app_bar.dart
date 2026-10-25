import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const BookingDetailAppBar(
      {super.key, required this.statusConfig, this.onMoreOptions});
  final BookingStatusPresentation statusConfig;
  final VoidCallback? onMoreOptions;
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text(
          'Chi tiết lịch hẹn',
          style: TextStyle(
            fontSize: AppFontSizes.s18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.shadow,
        leading: const AppBackButton(fallbackRoute: AppRoutes.bookings),
        actions: [
          Tooltip(
            message: statusConfig.label,
            child: Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: statusConfig.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: onMoreOptions,
          ),
        ],
      );
}
