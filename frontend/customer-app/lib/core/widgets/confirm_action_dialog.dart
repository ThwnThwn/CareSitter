import 'package:flutter/material.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';

/// Chỉ trả về true khi người dùng chọn rõ thao tác hủy hoặc xóa.
Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String keepLabel = 'Đóng',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.24),
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(maxWidth: 420),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            tooltip: keepLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            icon: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
                size: 12,
              ),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      content: Text(
        message,
        style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            textStyle: Theme.of(dialogContext)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w500),
            minimumSize: const Size(84, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: const BorderSide(color: AppColors.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(keepLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            textStyle: Theme.of(dialogContext)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w500),
            minimumSize: const Size(84, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
