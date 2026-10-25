import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CatalogScreenBanner extends StatelessWidget {
  const CatalogScreenBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.comfortable),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Expanded(child: _CatalogSupportCopy()),
          const SizedBox(width: AppSpacing.compact),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSupportCopy extends StatelessWidget {
  const _CatalogSupportCopy();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chưa biết chọn gói nào?',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.s16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'CareSitter hỗ trợ gia đình chọn dịch vụ phù hợp với nhu cầu sinh hoạt.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: AppFontSizes.s12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          const _CatalogContactPill(),
        ],
      );
}

class _CatalogContactPill extends StatelessWidget {
  const _CatalogContactPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inset,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_rounded, size: 13, color: AppColors.primary),
            SizedBox(width: 5),
            Text(
              'Tư vấn miễn phí: 1800 6789',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
