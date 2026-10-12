import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftSafetyContent extends StatelessWidget {
  const ShiftSafetyContent(
      {super.key,
      required this.safetyExpanded,
      required this.safetyItem,
      required this.callbackAction1});
  final bool safetyExpanded;
  final Widget Function(String) safetyItem;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          InkWell(
            onTap: callbackAction1,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.tight),
                    decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: const Icon(Icons.health_and_safety_outlined,
                        size: 18, color: AppColors.warning),
                  ),
                  const SizedBox(width: AppSpacing.control),
                  const Expanded(
                    child: Text('Quy tắc An toàn Phi Y tế',
                        style: TextStyle(
                            fontSize: AppFontSizes.s14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(
                    safetyExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (safetyExpanded)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.compact),
                  safetyItem(
                      'Không tự ý cho khách dùng thuốc ngoài danh sách được giao'),
                  safetyItem(
                      'Không di chuyển khách ra ngoài khu vực đã được phê duyệt'),
                  safetyItem(
                      'Báo cáo ngay nếu phát hiện triệu chứng bất thường'),
                  safetyItem('Tuân thủ quy trình check-in / check-out GPS'),
                ],
              ),
            ),
        ],
      );
}
