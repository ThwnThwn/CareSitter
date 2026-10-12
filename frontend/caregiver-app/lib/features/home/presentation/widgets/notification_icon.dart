import 'package:flutter/material.dart';

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key, required this.iconData});
  final Map<String, dynamic> iconData;

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconData['bg'] as Color,
          shape: BoxShape.circle,
        ),
        child: Icon(iconData['icon'] as IconData,
            color: iconData['color'] as Color),
      );
}
