import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingCaregiverContactActions extends StatelessWidget {
  const BookingCaregiverContactActions(
      {super.key,
      required this.callbackAction1,
      required this.callbackAction2});
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: callbackAction1,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 17, color: AppColors.primary),
                    SizedBox(width: AppSpacing.tight),
                    Text(
                      'Nhắn tin',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: AppFontSizes.s13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: InkWell(
              onTap: callbackAction2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call, size: 17, color: Colors.white),
                    SizedBox(width: AppSpacing.tight),
                    Text(
                      'Gọi trực tiếp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppFontSizes.s13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}
