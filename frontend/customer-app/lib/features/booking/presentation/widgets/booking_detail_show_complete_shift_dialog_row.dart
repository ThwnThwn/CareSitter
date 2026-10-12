import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingDetailShowCompleteShiftDialogRow extends StatelessWidget {
  const BookingDetailShowCompleteShiftDialogRow({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success, size: 26),
          SizedBox(width: AppSpacing.control),
          Text('Xác nhận hoàn thành',
              style: TextStyle(fontSize: AppFontSizes.s17)),
        ],
      );
}
