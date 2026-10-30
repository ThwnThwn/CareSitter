import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/support_chat/presentation/models/support_chat_labels.dart';
import 'package:caregiver_app/features/support_chat/presentation/support_chat_controller.dart';
import 'package:caregiver_app/features/support_chat/presentation/widgets/support_chat_header.dart';
import 'package:caregiver_app/features/support_chat/presentation/widgets/support_chat_layout.dart';
import 'package:caregiver_app/features/support_chat/presentation/widgets/support_chat_content.dart';
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
  late final ProviderSubscription<SupportChatState> _chatChanges;
  late final ProviderSubscription<String?> _accountChanges;

  bool get _nearBottom =>
      !_scrollController.hasClients ||
      _scrollController.position.extentAfter < AppSpacing.hero;

  void _markReadAtBottom() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > AppSpacing.lg) {
      return;
    }
    ref.read(supportChatControllerProvider.notifier).markVisibleRead();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_markReadAtBottom);
    _chatChanges =
        ref.listenManual(supportChatControllerProvider, _onChatChanged);
    _accountChanges = ref.listenManual(
        authStateProvider.select((value) => value.valueOrNull?.userId),
        (_, __) {
      _draft.clear();
      _subject.clear();
      _firstMessage.clear();
    });
  }

  void _onChatChanged(SupportChatState? previous, SupportChatState next) {
    final changedConversation =
        previous?.conversation?.id != next.conversation?.id;
    if (changedConversation) _draft.clear();
    final latest = next.messages.lastOrNull;
    if (latest == null ||
        (!changedConversation &&
            previous?.messages.lastOrNull?.id == latest.id)) {
      return;
    }
    if (changedConversation || _nearBottom || latest.senderRole != 'ADMIN') {
      _scrollToLatest();
    }
  }

  void _scrollToLatest() {
    final conversationId =
        ref.read(supportChatControllerProvider).conversation?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          ref.read(supportChatControllerProvider).conversation?.id !=
              conversationId) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_scrollController.hasClients ||
            ref.read(supportChatControllerProvider).conversation?.id !=
                conversationId) {
          return;
        }
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _markReadAtBottom();
      });
    });
  }

  @override
  void didChangeMetrics() {
    if (_nearBottom) _scrollToLatest();
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
    _chatChanges.close();
    _accountChanges.close();
    _subject.dispose();
    _firstMessage.dispose();
    _draft.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final draft = _draft.text;
    final chat = ref.read(supportChatControllerProvider);
    final conversation = chat.conversation;
    if (draft.trim().isEmpty ||
        chat.busy ||
        !chat.enabled ||
        conversation == null ||
        conversation.isClosed) {
      return;
    }
    final conversationId = conversation.id;
    await ref.read(supportChatControllerProvider.notifier).send(draft.trim());
    if (!mounted) return;
    final current = ref.read(supportChatControllerProvider);
    if (current.error == null &&
        current.conversation?.id == conversationId &&
        _draft.text == draft) {
      _draft.clear();
    }
  }

  void _showInfo() {
    final conversation = ref.read(supportChatControllerProvider).conversation;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Thông tin hội thoại',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              if (conversation != null) ...[
                Text(conversation.subject,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(SupportChatLabels.status(conversation)),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                  'Chat hỗ trợ không thay thế dịch vụ cấp cứu hoặc tư vấn y tế.'),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Đóng')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(supportChatControllerProvider);
    final controller = ref.read(supportChatControllerProvider.notifier);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SupportChatHeader(
        leading: const AppBackButton(fallbackRoute: '/settings/support'),
        toolbarHeight: SupportChatLayout.headerHeight * textScale.clamp(1, 1.6),
        status: chat.loading
            ? 'Đang tải cuộc trò chuyện…'
            : chat.enabled
                ? SupportChatLabels.status(chat.conversation)
                : 'Chat hỗ trợ',
        onRefresh: chat.loading ? null : controller.refresh,
        onInfo: _showInfo,
      ),
      body: SupportChatContent(
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
