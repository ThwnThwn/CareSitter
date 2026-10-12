import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenAppBar extends StatelessWidget {
  const RegisterScreenAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.compact, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppColors.textPrimary),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded,
                    color: AppColors.primary, size: 14),
                SizedBox(width: 5),
                Text(
                  'CareSitter',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSizes.s13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
