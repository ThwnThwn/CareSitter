import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SavedAddressDefaultAction extends StatelessWidget {
  const SavedAddressDefaultAction({super.key, required this.onSetDefault});
  final void Function() onSetDefault;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: onSetDefault,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border, size: 16, color: AppColors.primary),
                  SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Đặt làm mặc định',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: AppFontSizes.s12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]);
}
