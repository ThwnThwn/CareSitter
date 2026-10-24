import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/support_chat/presentation/support_chat_controller.dart';
import 'package:caresitter_customer/features/support_chat/presentation/support_chat_body.dart';
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
    if (chat.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markReadAtBottom();
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Chat hỗ trợ'),
          leading: const AppBackButton(fallbackRoute: AppRoutes.support),
          actions: [
            IconButton(
                tooltip: 'Làm mới',
                icon: const Icon(Icons.refresh),
                onPressed: () => controller.refresh())
          ]),
      body: SupportChatBody(
        state: chat,
        scrollController: _scrollController,
        subjectController: _subject,
        firstMessageController: _firstMessage,
        draftController: _draft,
        onRefresh: controller.refresh,
        onSend: _send,
        onCreate: () => controller.create(_subject.text, _firstMessage.text),
      ),
    );
  }
}
