import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_message_model.dart';
import 'package:flutter/material.dart';
import '../models/support_chat_labels.dart';
import 'support_chat_message.dart';

class SupportChatThread extends StatelessWidget {
  const SupportChatThread({
    super.key,
    required this.messages,
    required this.scrollController,
  });

  final List<SupportMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
              'Cuộc trò chuyện đã sẵn sàng.\nBạn có thể gửi tin nhắn đầu tiên.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('support-message-list'),
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index == 0 ? null : messages[index - 1];
        final differentDay = previous == null ||
            !DateUtils.isSameDay(
                previous.createdAt.toLocal(), message.createdAt.toLocal());
        final showAvatar =
            differentDay || previous.senderRole != message.senderRole;
        return Column(
          children: [
            if (differentDay) _DayDivider(day: message.createdAt),
            SupportChatMessage(
                key: ValueKey('support-message-${message.id}'),
                message: message,
                showAvatar: showAvatar),
          ],
        );
      },
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(SupportChatLabels.day(day),
              style: const TextStyle(
                  fontSize: AppFontSizes.s12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
      );
}
