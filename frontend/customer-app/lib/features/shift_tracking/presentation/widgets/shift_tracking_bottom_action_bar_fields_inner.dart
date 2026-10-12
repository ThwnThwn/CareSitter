import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingBottomActionBarFieldsInner extends StatelessWidget {
  const ShiftTrackingBottomActionBarFieldsInner({super.key});

  @override
  Widget build(BuildContext context) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: AppColors.textHint),
              SizedBox(width: AppSpacing.tight),
              Expanded(
                child: Text(
                  'Nút kết thúc mở sau khi người chăm sóc gửi báo cáo',
                  style: TextStyle(
                      fontSize: AppFontSizes.s11, color: AppColors.textHint),
                ),
              ),
            ],
          ),
        ],
      );
}
