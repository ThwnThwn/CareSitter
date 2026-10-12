import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class DisputePanel extends StatelessWidget {
  const DisputePanel({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          SizedBox(width: AppSpacing.control),
          Expanded(
              child: Text(
            'Khiếu nại sẽ được xem xét trong 24h. Chúng tôi sẽ liên hệ bạn qua số điện thoại đã đăng ký.',
            style: TextStyle(
                fontSize: AppFontSizes.s13,
                color: AppColors.warning,
                height: 1.4),
          )),
        ]),
      );
}
