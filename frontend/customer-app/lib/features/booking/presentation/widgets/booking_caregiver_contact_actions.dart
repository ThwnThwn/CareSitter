import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingCaregiverContactActions extends StatelessWidget {
  const BookingCaregiverContactActions(
      {super.key,
      required this.callbackAction1,
      required this.callbackAction2});
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ContactActionButton(
              onTap: callbackAction1,
              icon: Icons.chat_bubble_outline,
              label: 'Nhắn tin',
              foreground: AppColors.primary,
              background: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: _ContactActionButton(
              onTap: callbackAction2,
              icon: Icons.call,
              label: 'Gọi điện',
              foreground: Colors.white,
              background: AppColors.primary,
              elevated: true,
            ),
          ),
        ],
      );
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.elevated = false,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final bool elevated;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: AppSpacing.tight),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
