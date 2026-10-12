import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingAppBarMenu extends StatelessWidget {
  const ShiftTrackingAppBarMenu({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
            ],
          ),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 20, color: AppColors.textPrimary),
                onPressed: () {},
              ),
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
