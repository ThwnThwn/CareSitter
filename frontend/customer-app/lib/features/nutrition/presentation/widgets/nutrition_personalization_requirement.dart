import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../domain/nutrition_personalization_rules.dart';

/// Readiness/Safety banner theo Stitch design:
/// gradient xanh nhạt, shield icon xanh solid, typography rõ ràng.
class NutritionPersonalizationRequirement extends StatelessWidget {
  const NutritionPersonalizationRequirement(
      {super.key, required this.readiness});

  final NutritionPersonalizationReadiness readiness;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: readiness.isReady
            ? 'Đã hoàn tất thông tin bắt buộc cho gợi ý thực đơn'
            : 'Cần hoàn tất thông tin bắt buộc cho gợi ý thực đơn',
        child: _RequirementBanner(readiness: readiness),
      );
}

class _RequirementBanner extends StatelessWidget {
  const _RequirementBanner({required this.readiness});

  final NutritionPersonalizationReadiness readiness;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: readiness.isReady
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEAF7F2), Color(0xFFE8F9F4)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: readiness.isReady
                ? const Color(0xFFA7D9C5)
                : const Color(0xFFFCD34D),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RequirementIcon(isReady: readiness.isReady),
            const SizedBox(width: AppSpacing.compact),
            Expanded(child: _RequirementCopy(readiness: readiness)),
          ],
        ),
      );
}

class _RequirementIcon extends StatelessWidget {
  const _RequirementIcon({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isReady ? AppColors.primary : AppColors.warning,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isReady ? Icons.verified_rounded : Icons.info_outline_rounded,
          color: Colors.white,
          size: 16,
        ),
      );
}

class _RequirementCopy extends StatelessWidget {
  const _RequirementCopy({required this.readiness});

  final NutritionPersonalizationReadiness readiness;

  Color get _color =>
      readiness.isReady ? AppColors.primaryDark : const Color(0xFF92400E);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            readiness.isReady
                ? 'Đã sẵn sàng kiểm tra thông tin'
                : 'Hoàn tất thông tin bắt buộc',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Thông tin đã xác nhận được dùng để đối chiếu món ăn phù hợp. '
            'Ứng dụng không chẩn đoán bệnh.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: _color),
          ),
          if (!readiness.isReady) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final field in readiness.missingFields)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '• $field',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _color,
                      ),
                ),
              ),
          ],
        ],
      );
}
