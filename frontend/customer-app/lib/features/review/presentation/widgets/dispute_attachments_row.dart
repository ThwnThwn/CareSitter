import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class DisputeAttachmentsRow extends StatelessWidget {
  const DisputeAttachmentsRow({super.key, required this.attachments});
  final List<XFile> attachments;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Đính kèm bằng chứng (tuỳ chọn)',
              style: TextStyle(
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text('${attachments.length}/5 tệp',
              style: const TextStyle(
                  fontSize: AppFontSizes.s12, color: AppColors.textSecondary)),
        ],
      );
}
