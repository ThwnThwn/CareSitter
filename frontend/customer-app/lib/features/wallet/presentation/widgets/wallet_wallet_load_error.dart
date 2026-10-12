import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class WalletWalletLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const WalletWalletLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.compact),
            const Text(
              'Không tải được thông tin ví',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
