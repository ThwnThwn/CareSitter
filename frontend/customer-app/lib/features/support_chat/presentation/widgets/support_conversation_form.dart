import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'support_chat_avatar.dart';

class SupportConversationForm extends StatelessWidget {
  const SupportConversationForm({
    super.key,
    required this.subjectController,
    required this.firstMessageController,
    required this.busy,
    required this.onCreate,
    this.onCancel,
  });

  final TextEditingController subjectController;
  final TextEditingController firstMessageController;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SupportChatAvatar(size: AppSpacing.hero)),
            const SizedBox(height: AppSpacing.lg),
            const Text('Bạn cần hỗ trợ điều gì?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFontSizes.s20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
                'Gửi yêu cầu để đội ngũ CareSitter tiếp nhận và phản hồi ngay tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: subjectController,
              enabled: !busy,
              maxLength: 255,
              decoration: const InputDecoration(
                  labelText: 'Chủ đề cần hỗ trợ', counterText: ''),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: firstMessageController,
              enabled: !busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                  labelText: 'Nội dung yêu cầu', alignLabelWithHint: true),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: busy ? null : onCreate,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.xxl),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary),
              child: Text(busy ? 'Đang gửi yêu cầu…' : 'Bắt đầu hội thoại'),
            ),
            if (onCancel != null)
              TextButton(
                  onPressed: busy ? null : onCancel,
                  child: const Text('Quay lại hội thoại')),
          ],
        ),
      );
}
