import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionRequiredHeader extends StatelessWidget {
  const NutritionRequiredHeader({super.key});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Thông tin bắt buộc cho gợi ý cá nhân hóa',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hãy xác nhận bệnh lý và dị ứng đã biết. Khi có thông tin, ghi rõ '
              'để hệ thống loại các món không phù hợp; không dùng mục này để tự chẩn đoán.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}
