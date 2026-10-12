import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Trạng thái lỗi tải dữ liệu đánh giá kèm nút thử lại.
class ReviewLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const ReviewLoadError({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: AppSpacing.compact),
            const Text(
              'Không tải được đánh giá',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
