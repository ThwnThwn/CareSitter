import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/support_chat/presentation/support_chat_controller.dart';
import 'package:caresitter_customer/features/support_chat/presentation/widgets/support_chat_composer.dart';
import 'package:caresitter_customer/features/support_chat/presentation/widgets/support_chat_layout.dart';
import 'package:caresitter_customer/features/support_chat/presentation/widgets/support_chat_loading.dart';
import 'package:caresitter_customer/features/support_chat/presentation/widgets/support_chat_thread.dart';
import 'package:caresitter_customer/features/support_chat/presentation/widgets/support_conversation_form.dart';
import 'package:flutter/material.dart';

class SupportChatBody extends StatefulWidget {
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
  State<SupportChatBody> createState() => _SupportChatBodyState();
}

class _SupportChatBodyState extends State<SupportChatBody> {
  bool _creatingNew = false;

  @override
  void didUpdateWidget(covariant SupportChatBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.conversation?.id != widget.state.conversation?.id) {
      _creatingNew = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.state;
    if (chat.loading) return const SupportChatLoading();
    if (!chat.enabled) {
      return _UnavailableChat(error: chat.error, onRetry: widget.onRefresh);
    }
    final conversation = chat.conversation;
    final creating = conversation == null || _creatingNew;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: SupportChatLayout.maxWidth),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 400 ||
              MediaQuery.viewInsetsOf(context).bottom > 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (chat.error != null)
                _ChatError(message: chat.error!, onRetry: widget.onRefresh),
              if (!creating && !compact) _Topic(subject: conversation.subject),
              Expanded(
                child: creating
                    ? SupportConversationForm(
                        subjectController: widget.subjectController,
                        firstMessageController: widget.firstMessageController,
                        busy: chat.busy,
                        onCreate: widget.onCreate,
                        onCancel: conversation == null
                            ? null
                            : () => setState(() => _creatingNew = false))
                    : SupportChatThread(
                        messages: chat.messages,
                        scrollController: widget.scrollController),
              ),
              _ChatFooter(
                compact: compact,
                child: creating
                    ? null
                    : conversation.isClosed
                        ? _ClosedConversation(
                            onCreate: () => setState(() => _creatingNew = true))
                        : SupportChatComposer(
                            controller: widget.draftController,
                            busy: chat.busy,
                            onSend: widget.onSend),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Topic extends StatelessWidget {
  const _Topic({required this.subject});
  final String subject;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.compact, AppSpacing.md, AppSpacing.xs),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Tooltip(
                message: subject,
                excludeFromSemantics: true,
                child: Text(subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
        ),
      );
}

class _ChatFooter extends StatelessWidget {
  const _ChatFooter({required this.compact, required this.child});
  final bool compact;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (child != null) child!,
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.xs, AppSpacing.md, AppSpacing.compact),
                  child: Text(
                    'Chat hỗ trợ không thay thế dịch vụ cấp cứu hoặc tư vấn y tế.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _ClosedConversation extends StatelessWidget {
  const _ClosedConversation({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hội thoại đã kết thúc và hiện chỉ có thể xem lại.',
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Gửi yêu cầu mới')),
          ],
        ),
      );
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.errorLight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.error)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}

class _UnavailableChat extends StatelessWidget {
  const _UnavailableChat({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                  error == null
                      ? 'Chat hỗ trợ hiện chưa mở'
                      : 'Chưa kết nối được cuộc trò chuyện',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(error ?? 'Vui lòng quay lại trang hỗ trợ hoặc thử lại sau.',
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại')),
            ],
          ),
        ),
      );
}
