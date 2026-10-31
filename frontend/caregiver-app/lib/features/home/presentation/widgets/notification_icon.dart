import 'package:flutter/material.dart';
import 'package:caregiver_app/features/home/presentation/models/notification_visual.dart';

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key, required this.visual});
  final NotificationVisual visual;

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: visual.background,
          shape: BoxShape.circle,
        ),
        child: Icon(visual.icon, color: visual.foreground),
      );
}
