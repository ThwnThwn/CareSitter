import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const BookingDetailAppBar(
      {super.key,
      required this.statusConfig,
      required this.isCancelling,
      required this.cancelDialogOpen,
      required this.showMoreOptions,
      required this.ref,
      required this.booking});
  final BookingStatusPresentation statusConfig;
  final bool isCancelling;
  final bool cancelDialogOpen;
  final void Function(BuildContext, WidgetRef, BookingModel) showMoreOptions;
  final WidgetRef ref;
  final BookingModel booking;
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
        leading: const AppBackButton(fallbackRoute: '/bookings'),
        actions: [
          // Status badge chip in header (matching Stitch)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 11),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.control, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: statusConfig.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: statusConfig.color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusConfig.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusConfig.label,
                  style: TextStyle(
                    color: statusConfig.color,
                    fontSize: AppFontSizes.s11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: isCancelling || cancelDialogOpen
                ? null
                : () => showMoreOptions(context, ref, booking),
          ),
        ],
      );
}
