import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';

class SupportChatComposer extends StatelessWidget {
  const SupportChatComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final canSend = !busy && value.text.trim().isNotEmpty;
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                AppSpacing.compact, AppSpacing.md, AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('support-message-input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSend) onSend();
                    },
                    style: const TextStyle(
                        fontSize: AppFontSizes.s15,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn…',
                      semanticCounterText: '${value.text.length}/2000 ký tự',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.inset),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: AppSpacing.xxl,
                  width: AppSpacing.xxl,
                  child: IconButton.filled(
                    tooltip: busy ? 'Đang gửi tin nhắn' : 'Gửi tin nhắn',
                    onPressed: canSend ? onSend : null,
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.primaryContainer,
                        disabledForegroundColor: AppColors.textSecondary),
                    icon: busy
                        ? const SizedBox(
                            width: AppSpacing.section,
                            height: AppSpacing.section,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
