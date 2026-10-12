import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/home/presentation/controllers/notifications_controller.dart';

class HomeNotificationButton extends StatelessWidget {
  const HomeNotificationButton(
      {super.key,
      required this.ref,
      required this.callbackAction1,
      required this.callbackAction2});
  final WidgetRef ref;
  final bool Function(AppNotificationModel) callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Builder(builder: (context) {
        final notifications = ref.watch(notificationsProvider);
        final unread = notifications.where(callbackAction1).length;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.textPrimary),
              onPressed: callbackAction2,
            ),
            if (unread > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.cardBackground, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      });
}
