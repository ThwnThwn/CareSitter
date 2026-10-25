import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'booking_step_counter.dart';

class BookingWizardHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const BookingWizardHeader({
    super.key,
    required this.step,
    required this.onClose,
  });

  final int step;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: AppColors.surfaceVariant,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: onClose,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      title: const Text(
        'Đặt lịch hỗ trợ',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        BookingStepCounter(step: step),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }
}
