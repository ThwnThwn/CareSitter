import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast_type.dart';

class ToastMessageContent extends StatelessWidget {
  const ToastMessageContent({
    super.key,
    required this.surface,
    required this.accent,
    required this.type,
    required this.icon,
    required this.title,
    this.message,
    required this.callbackAction1,
  });

  final Color surface;
  final Color accent;
  final AppToastType type;
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback callbackAction1;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.inset,
            AppSpacing.compact,
            AppSpacing.sm,
            AppSpacing.compact,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: AppSpacing.lg,
                  height: AppSpacing.lg,
                  margin: const EdgeInsets.only(top: AppSpacing.micro),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.onPrimary, size: 16),
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.micro),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (message case final description?) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.s13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: callbackAction1,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Đóng',
                constraints: const BoxConstraints.tightFor(
                  width: AppSpacing.s40,
                  height: AppSpacing.s40,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
}
