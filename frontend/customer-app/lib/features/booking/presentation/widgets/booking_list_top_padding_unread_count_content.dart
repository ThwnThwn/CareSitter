import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
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
              GestureDetector(
                onTap: () => context.push(AppRoutes.notifications),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                    if (unreadCount > 0)
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
