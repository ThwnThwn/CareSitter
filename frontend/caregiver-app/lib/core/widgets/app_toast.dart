import 'package:caregiver_app/core/widgets/app_toast_type.dart';
export 'package:caregiver_app/core/widgets/app_toast_type.dart';
import 'package:caregiver_app/core/widgets/toast_message_content.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:caregiver_app/core/widgets/app_messenger.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Toast nổi dùng cho các thao tác quan trọng; mỗi lần hiển thị thay thế toast trước đó.
final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void loading(BuildContext context, String message) => _show(context,
      message: message,
      type: AppToastType.loading,
      duration: const Duration(days: 1));
  static void success(BuildContext context, String message) =>
      _show(context, message: message, type: AppToastType.success);
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
      appMessengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);

  static void _show(BuildContext context,
      {required String message,
      required AppToastType type,
      Duration duration = const Duration(seconds: 4)}) {
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
    final overlayContext = appMessengerKey.currentContext ?? context;
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final reducedMotion =
            MediaQuery.maybeOf(overlayContext)?.disableAnimations ?? false;
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 12,
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
              child: ToastMessageContent(
                  surface: surface,
                  accent: accent,
                  type: type,
                  icon: icon,
                  message: message,
                  callbackAction1: () => _remove(entry)),
            ),
          ),
        );
      },
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
