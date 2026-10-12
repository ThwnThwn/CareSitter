import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Primary CTA button – full width by default
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primary;
    final fgColor = foregroundColor ?? Colors.white;

    Widget child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(fgColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final style = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: bgColor,
            side: BorderSide(color: bgColor, width: 1.5),
            minimumSize: Size(width ?? double.infinity, height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            minimumSize: Size(width ?? double.infinity, height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          );

    return isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed, style: style, child: child)
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child);
  }
}
