import 'package:caresitter_customer/core/widgets/app_tab_header.dart';
import 'package:caresitter_customer/core/widgets/notification_bell_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

class BookingListTopPaddingUnreadCountContent extends StatelessWidget {
  const BookingListTopPaddingUnreadCountContent(
      {super.key, required this.topPadding, required this.unreadCount});
  final double topPadding;
  final int unreadCount;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: AppTabHeader(
          title: 'Quản lý Lịch hẹn',
          topPadding: topPadding,
          actions: [
            NotificationBellButton(
              unreadCount: unreadCount,
              onPressed: () => context.push(AppRoutes.notifications),
            ),
          ],
        ),
      );
}
