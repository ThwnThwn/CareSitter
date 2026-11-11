import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/widgets/notification_bell_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

class BookingListTopPaddingUnreadCountContent extends StatelessWidget {
  const BookingListTopPaddingUnreadCountContent(
      {super.key, required this.topPadding, required this.unreadCount});
  final double topPadding;
  final int unreadCount;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Container(
          color: AppColors.background,
          padding: EdgeInsets.only(
            top: topPadding + 16,
            left: AppSpacing.section,
            right: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Quản lý Lịch hẹn',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.s22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              NotificationBellButton(
                unreadCount: unreadCount,
                onPressed: () => context.push(AppRoutes.notifications),
              ),
            ],
          ),
        ),
      );
}
