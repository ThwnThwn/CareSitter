import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingAppBarTitle extends StatelessWidget {
  const ShiftTrackingAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inset, vertical: AppSpacing.tight),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 900),
              builder: (_, v, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: v),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.tight),
            const Flexible(
              child: Text(
                'Theo dõi ca chăm sóc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
