import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppToastType { success, error, loading }

/// Toast nổi dùng cho các thao tác quan trọng; mỗi lần hiển thị thay thế toast trước đó.
final class AppToast {
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
  static void dismiss(BuildContext context) =>
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: duration,
        content: Semantics(
            liveRegion: true,
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
                        offset: const Offset(0, 3))
                  ]),
              child: Row(children: [
                if (type == AppToastType.loading)
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: accent))
                else
                  Icon(icon, color: accent, size: 21),
                const SizedBox(width: 11),
                Expanded(
                    child: Text(message,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.35))),
                if (type != AppToastType.loading)
                  IconButton(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textSecondary),
                      tooltip: 'Đóng',
                      visualDensity: VisualDensity.compact),
              ]),
            )),
      ));
  }
}
