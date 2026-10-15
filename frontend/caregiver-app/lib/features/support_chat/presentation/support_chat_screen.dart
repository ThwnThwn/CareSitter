import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/support_chat/presentation/support_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen>
    with WidgetsBindingObserver {
  final _subject = TextEditingController();
  final _firstMessage = TextEditingController();
  final _draft = TextEditingController();
  final _scrollController = ScrollController();

  void _markReadAtBottom() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 24) {
      return;
    }
    ref.read(supportChatControllerProvider.notifier).markVisibleRead();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_markReadAtBottom);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(supportChatControllerProvider.notifier)
        .setActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subject.dispose();
    _firstMessage.dispose();
    _draft.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    await ref.read(supportChatControllerProvider.notifier).send(text);
    if (mounted && ref.read(supportChatControllerProvider).error == null) {
      _draft.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(supportChatControllerProvider);
    final controller = ref.read(supportChatControllerProvider.notifier);
    final conversation = chat.conversation;
    if (chat.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markReadAtBottom();
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Chat hỗ trợ'),
          leading: const AppBackButton(fallbackRoute: '/settings/support'),
          actions: [
            IconButton(
                tooltip: 'Làm mới',
                icon: const Icon(Icons.refresh),
                onPressed: () => controller.refresh())
          ]),
      body: chat.loading
          ? const Center(child: CircularProgressIndicator())
          : !chat.enabled
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'Chat hỗ trợ hiện chưa mở. Vui lòng quay lại trang hỗ trợ.')))
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                      if (chat.error != null)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(chat.error!,
                                          style: const TextStyle(
                                              color: AppColors.error)),
                                      TextButton(
                                          onPressed: () => controller.refresh(),
                                          child: const Text('Thử lại')),
                                    ]))),
                      if (conversation != null) ...[
                        Text(conversation.subject,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(conversation.isClosed
                            ? 'Đã kết thúc'
                            : conversation.status == 'NEW'
                                ? 'Đang chờ tiếp nhận'
                                : 'Đang xử lý'),
                        const SizedBox(height: AppSpacing.md),
                        if (chat.messages.isEmpty)
                          const Text('Đang tải tin nhắn…'),
                        for (final message in chat.messages)
                          Align(
                              alignment: message.senderRole == 'ADMIN'
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Card(
                                  child: Padding(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.md),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                message.senderRole == 'ADMIN'
                                                    ? 'CareSitter'
                                                    : 'Bạn',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(message.body),
                                          ])))),
                      ],
                      if (conversation != null && !conversation.isClosed) ...[
                        TextField(
                            controller: _draft,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                                labelText: 'Nhập tin nhắn')),
                        FilledButton(
                            onPressed: chat.busy ? null : _send,
                            child: const Text('Gửi tin nhắn')),
                      ],
                      if (conversation == null || conversation.isClosed) ...[
                        if (conversation?.isClosed == true)
                          const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(
                                  'Hội thoại trước chỉ đọc. Bạn có thể gửi yêu cầu mới.')),
                        TextField(
                            controller: _subject,
                            maxLength: 255,
                            decoration: const InputDecoration(
                                labelText: 'Chủ đề cần hỗ trợ')),
                        TextField(
                            controller: _firstMessage,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                                labelText: 'Nội dung yêu cầu')),
                        FilledButton(
                            onPressed: chat.busy
                                ? null
                                : () => controller.create(
                                    _subject.text, _firstMessage.text),
                            child: const Text('Bắt đầu hội thoại')),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                          'Chat hỗ trợ không thay thế dịch vụ cấp cứu hoặc tư vấn y tế.'),
                    ]),
    );
  }
}
