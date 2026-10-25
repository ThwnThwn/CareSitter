import 'dart:async';

import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_messenger.dart';
import 'package:caregiver_app/core/widgets/app_toast_type.dart';
import 'package:caregiver_app/core/widgets/toast_message_content.dart';

export 'package:caregiver_app/core/widgets/app_toast_type.dart';

/// Toast nổi cho phản hồi thao tác. Mỗi toast mới thay thế toast trước đó.
final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void info(
    BuildContext context,
    String message, {
    String? title,
  }) =>
      _show(
        context,
        title: title ?? 'Đang xử lý',
        message: message,
        type: AppToastType.info,
        duration: const Duration(days: 1),
      );

  /// Giữ tương thích các luồng cũ trong khi dùng giao diện toast thông tin.
  static void loading(BuildContext context, String message) =>
      info(context, message);

  static void success(BuildContext context, String message) => _show(
        context,
        title: message,
        type: AppToastType.success,
      );

  static void error(
    BuildContext context,
    String message, {
    String? title,
  }) =>
      _show(
        context,
        title: title ?? message,
        message: title == null ? null : message,
        type: AppToastType.error,
        duration: const Duration(seconds: 5),
      );

  static void dismiss(BuildContext context) {
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;
    _messengerFor(context)?.hideCurrentSnackBar();
  }

  static ScaffoldMessengerState? _messengerFor(BuildContext context) =>
      appMessengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);

  static void _show(
    BuildContext context, {
    required String title,
    String? message,
    required AppToastType type,
    Duration duration = const Duration(seconds: 4),
  }) {
    final (icon, accent) = switch (type) {
      AppToastType.success => (Icons.check_rounded, AppColors.success),
      AppToastType.error => (Icons.close_rounded, AppColors.error),
      AppToastType.info => (Icons.info_rounded, AppColors.info),
    };
    dismiss(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
        (appMessengerKey.currentContext == null
            ? null
            : Overlay.maybeOf(
                appMessengerKey.currentContext!,
                rootOverlay: true,
              ));
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final reducedMotion =
            MediaQuery.maybeOf(overlayContext)?.disableAnimations ?? false;
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top +
              kToolbarHeight +
              AppSpacing.compact,
          left: AppSpacing.md,
          right: AppSpacing.md,
          child: Semantics(
            liveRegion: true,
            child: TweenAnimationBuilder<double>(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -24 * (1 - value)),
                  child: child,
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ToastMessageContent(
                    surface: AppColors.surface,
                    accent: accent,
                    type: type,
                    icon: icon,
                    title: title,
                    message: message,
                    callbackAction1: () => _remove(entry),
                  ),
                ),
              ),
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
