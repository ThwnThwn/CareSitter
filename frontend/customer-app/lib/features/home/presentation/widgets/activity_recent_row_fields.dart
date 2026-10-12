import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ActivityRecentRowFields extends StatelessWidget {
  const ActivityRecentRowFields({super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.tight),
            GestureDetector(
              onTap: callbackAction1,
              child: const Text(
                'Đặt lại →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]);
}
