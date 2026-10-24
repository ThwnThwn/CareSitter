import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/support_chat/data/support_chat_repository.dart';
import 'package:caresitter_customer/features/support_chat/presentation/support_chat_controller.dart';
import 'package:flutter/material.dart';

class SupportChatBody extends StatelessWidget {
  const SupportChatBody({
    super.key,
    required this.state,
    required this.scrollController,
    required this.subjectController,
    required this.firstMessageController,
    required this.draftController,
    required this.onRefresh,
    required this.onSend,
    required this.onCreate,
  });

  final SupportChatState state;
  final ScrollController scrollController;
  final TextEditingController subjectController;
  final TextEditingController firstMessageController;
  final TextEditingController draftController;
  final VoidCallback onRefresh;
  final VoidCallback onSend;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.enabled) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Chat hỗ trợ hiện chưa mở. Vui lòng quay lại trang hỗ trợ.',
          ),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (state.error != null)
          _ChatError(message: state.error!, onRetry: onRefresh),
        if (state.conversation != null)
          _ConversationContent(
            conversation: state.conversation!,
            messages: state.messages,
          ),
        if (state.conversation != null && !state.conversation!.isClosed)
          _MessageComposer(
            controller: draftController,
            busy: state.busy,
            onSend: onSend,
          ),
        if (state.conversation == null || state.conversation!.isClosed)
          _ConversationComposer(
            showClosedNotice: state.conversation?.isClosed == true,
            subjectController: subjectController,
            firstMessageController: firstMessageController,
            busy: state.busy,
            onCreate: onCreate,
          ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Chat hỗ trợ không thay thế dịch vụ cấp cứu hoặc tư vấn y tế.',
        ),
      ],
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: AppColors.error)),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}

class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.conversation,
    required this.messages,
  });

  final SupportConversation conversation;
  final List<SupportMessage> messages;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(conversation.subject,
              style: Theme.of(context).textTheme.titleLarge),
          Text(_statusLabel(conversation)),
          const SizedBox(height: AppSpacing.md),
          if (messages.isEmpty) const Text('Đang tải tin nhắn…'),
          for (final message in messages) _MessageBubble(message: message),
        ],
      );

  static String _statusLabel(SupportConversation conversation) {
    if (conversation.isClosed) return 'Đã kết thúc';
    return conversation.status == 'NEW' ? 'Đang chờ tiếp nhận' : 'Đang xử lý';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) => Align(
        alignment: message.senderRole == 'ADMIN'
            ? Alignment.centerLeft
            : Alignment.centerRight,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderRole == 'ADMIN' ? 'CareSitter' : 'Bạn',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(message.body),
              ],
            ),
          ),
        ),
      );
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Nhập tin nhắn'),
          ),
          FilledButton(
            onPressed: busy ? null : onSend,
            child: const Text('Gửi tin nhắn'),
          ),
        ],
      );
}

class _ConversationComposer extends StatelessWidget {
  const _ConversationComposer({
    required this.showClosedNotice,
    required this.subjectController,
    required this.firstMessageController,
    required this.busy,
    required this.onCreate,
  });

  final bool showClosedNotice;
  final TextEditingController subjectController;
  final TextEditingController firstMessageController;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showClosedNotice)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'Hội thoại trước chỉ đọc. Bạn có thể gửi yêu cầu mới.',
              ),
            ),
          TextField(
            controller: subjectController,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Chủ đề cần hỗ trợ'),
          ),
          TextField(
            controller: firstMessageController,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Nội dung yêu cầu'),
          ),
          FilledButton(
            onPressed: busy ? null : onCreate,
            child: const Text('Bắt đầu hội thoại'),
          ),
        ],
      );
}
