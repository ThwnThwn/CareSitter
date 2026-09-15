import 'dart:async';

import 'package:flutter/material.dart';

import '../../push/notification_deep_link_service.dart';
import '../../theme/app_theme.dart';

enum AppToastType { success, error, loading }

/// Toast nổi dùng cho các thao tác quan trọng; mỗi lần hiển thị thay thế toast trước đó.
final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void loading(BuildContext context, String message) => _show(
        context,
        message: message,
        type: AppToastType.loading,
        duration: const Duration(days: 1),
      );

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(
        context,
        message: message,
        type: AppToastType.success,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void error(BuildContext context, String message) => _show(context,
      message: message,
      type: AppToastType.error,
      duration: const Duration(seconds: 5));

  static void dismiss(BuildContext context) {
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;
    _messengerFor(context)?.hideCurrentSnackBar();
  }

  static ScaffoldMessengerState? _messengerFor(BuildContext context) =>
      notificationMessengerKey.currentState ??
      ScaffoldMessenger.maybeOf(context);

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final (icon, accent, surface) = switch (type) {
      AppToastType.success => (
          Icons.check_circle_rounded,
          AppColors.success,
          AppColors.successLight
        ),
      AppToastType.error => (
          Icons.error_rounded,
          AppColors.error,
          AppColors.error.withValues(alpha: .10)
        ),
      AppToastType.loading => (
          Icons.hourglass_top_rounded,
          AppColors.primary,
          AppColors.primary.withValues(alpha: .10)
        ),
    };
    dismiss(context);
    final overlayContext = notificationMessengerKey.currentContext ?? context;
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopToast(
        icon: icon,
        accent: accent,
        surface: surface,
        message: message,
        isLoading: type == AppToastType.loading,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () => _remove(entry),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, () => _remove(entry));
  }

  static void _remove(OverlayEntry entry) {
    if (_entry != entry) return;
    _dismissTimer?.cancel();
    entry.remove();
    _entry = null;
  }
}

class _TopToast extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color surface;
  final String message;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.message,
    required this.isLoading,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Semantics(
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
                      onPressed: () {
                        onDismiss();
                        onAction!();
                      },
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
      ),
    );
  }
}
