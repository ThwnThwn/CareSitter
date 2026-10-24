import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CaregiverListUnreadCountContent extends StatelessWidget {
  const CaregiverListUnreadCountContent({super.key, required this.unreadCount});
  final int unreadCount;
  @override
  Widget build(BuildContext context) => GestureDetector(
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
              child: const Icon(Icons.notifications_outlined,
                  color: AppColors.textSecondary, size: 22),
            ),
            if (unreadCount > 0)
              const Positioned(
                right: 6,
                top: 6,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: AppColors.legacyError,
                ),
              ),
          ],
        ),
      );
}
