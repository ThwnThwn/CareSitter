import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LiveMapActionButton extends StatelessWidget {
  const LiveMapActionButton(
      {super.key,
      required this.tooltip,
      required this.icon,
      this.onPressed,
      this.active = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  @override
  Widget build(BuildContext context) => Material(
        color: active ? AppColors.primaryContainer : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.compact),
            side: const BorderSide(color: AppColors.border)),
        child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: AppColors.primary,
            icon: Icon(icon, size: 21),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44)),
      );
}
