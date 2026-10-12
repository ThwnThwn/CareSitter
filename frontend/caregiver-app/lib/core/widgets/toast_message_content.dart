import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/widgets/app_toast_type.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ToastMessageContent extends StatelessWidget {
  const ToastMessageContent(
      {super.key,
      required this.surface,
      required this.accent,
      required this.type,
      required this.icon,
      required this.message,
      required this.callbackAction1});
  final Color surface;
  final Color accent;
  final AppToastType type;
  final IconData icon;
  final String message;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.inset, vertical: AppSpacing.compact),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: accent.withValues(alpha: .24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              if (type == AppToastType.loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accent,
                  ),
                )
              else
                Icon(icon, color: accent, size: 21),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSizes.s13,
                    height: 1.35,
                  ),
                ),
              ),
              if (type != AppToastType.loading)
                IconButton(
                  onPressed: callbackAction1,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Đóng',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      );
}
