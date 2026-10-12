import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingBottomActionBarFields extends StatelessWidget {
  const ShiftTrackingBottomActionBarFields(
      {super.key,
      required this.callbackAction1,
      required this.callbackAction2});
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: callbackAction1,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text(
              'Gửi tin nhắn',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: AppFontSizes.s14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              elevation: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.tight),
          InkWell(
            onTap: callbackAction2,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 13, color: AppColors.error),
                  SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Báo cáo sự cố hoặc liên hệ giám sát viên 24/7',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.s11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
