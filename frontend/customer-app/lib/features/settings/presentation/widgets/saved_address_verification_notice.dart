import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SavedAddressVerificationNotice extends StatelessWidget {
  const SavedAddressVerificationNotice({super.key});

  @override
  Widget build(BuildContext context) => const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.tight),
            Text(
              'Cần chọn lại từ danh sách gợi ý trước khi đặt lịch.',
              style: TextStyle(
                  color: AppColors.warning, fontSize: AppFontSizes.s12),
            ),
          ]);
}
