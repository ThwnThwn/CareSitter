import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ToastMessageContent extends StatelessWidget {
  const ToastMessageContent(
      {super.key,
      required this.reducedMotion,
      required this.surface,
      required this.accent,
      required this.isLoading,
      required this.icon,
      required this.message,
      required this.actionLabel,
      required this.onAction,
      required this.onDismiss,
      required this.callbackAction1});
  final bool reducedMotion;
  final Color surface;
  final Color accent;
  final bool isLoading;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final void Function()? onAction;
  final void Function() onDismiss;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: TweenAnimationBuilder<double>(
          duration:
              reducedMotion ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -24 * (1 - value)),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
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
                  if (isLoading)
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
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (!isLoading && actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: callbackAction1,
                      child: Text(actionLabel!),
                    ),
                  if (!isLoading)
                    IconButton(
                      onPressed: onDismiss,
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
          ),
        ),
      );
}
