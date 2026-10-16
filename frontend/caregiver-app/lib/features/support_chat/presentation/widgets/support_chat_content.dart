import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/support_chat/data/support_chat_repository.dart';
import 'package:caregiver_app/features/support_chat/presentation/support_chat_controller.dart';
import 'package:flutter/material.dart';

class SupportChatContent extends StatelessWidget {
  const SupportChatContent({
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
  final Future<void> Function() onSend;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.enabled) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.section),
          child: Text(
            'Chat hỗ trợ hiện chưa mở. Vui lòng quay lại trang hỗ trợ.',
          ),
        ),
      );
    }
    final conversation = state.conversation;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (state.error case final error?)
          _SupportErrorCard(error: error, onRetry: onRefresh),
        if (conversation != null)
          _ConversationSummary(
            conversation: conversation,
            messages: state.messages,
          ),
        if (conversation != null && !conversation.isClosed)
          _MessageComposer(
            controller: draftController,
            busy: state.busy,
            onSend: onSend,
          ),
        if (conversation == null || conversation.isClosed)
          _ConversationRequestForm(
            showClosedNotice: conversation?.isClosed == true,
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

class _SupportErrorCard extends StatelessWidget {
  const _SupportErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error, style: const TextStyle(color: AppColors.error)),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _ConversationSummary extends StatelessWidget {
  const _ConversationSummary({
    required this.conversation,
    required this.messages,
  });

  final SupportConversation conversation;
  final List<SupportMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          conversation.subject,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(_statusText),
        const SizedBox(height: AppSpacing.md),
        if (messages.isEmpty)
          const Text('Đang tải tin nhắn…')
        else
          for (final message in messages) _SupportMessageCard(message: message),
      ],
    );
  }

  String get _statusText {
    if (conversation.isClosed) return 'Đã kết thúc';
    return conversation.status == 'NEW' ? 'Đang chờ tiếp nhận' : 'Đang xử lý';
  }
}

class _SupportMessageCard extends StatelessWidget {
  const _SupportMessageCard({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final fromAdmin = message.senderRole == 'ADMIN';
    return Align(
      alignment: fromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fromAdmin ? 'CareSitter' : 'Bạn',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(message.body),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
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
}

class _ConversationRequestForm extends StatelessWidget {
  const _ConversationRequestForm({
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
  Widget build(BuildContext context) {
    return Column(
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
}
