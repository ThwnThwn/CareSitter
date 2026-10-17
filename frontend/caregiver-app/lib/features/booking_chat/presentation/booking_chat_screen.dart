import 'dart:async';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caregiver_app/features/booking_chat/presentation/booking_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BookingChatScreen extends ConsumerStatefulWidget {
  const BookingChatScreen({super.key, required this.bookingId,
      this.bookingTitle});
  final String bookingId;
  final String? bookingTitle;

  @override
  ConsumerState<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends ConsumerState<BookingChatScreen>
    with WidgetsBindingObserver {
  final _draft = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingMore = false;

  BookingChatController get _ctrl =>
      ref.read(bookingChatControllerProvider(widget.bookingId).notifier);

  void _markReadAtBottom() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 40) return;
    unawaited(_ctrl.markVisibleRead());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(() {
      _markReadAtBottom();
      if (_scrollController.position.extentBefore < 120 && !_loadingMore) {
        _loadingMore = true;
        _ctrl.loadMore().whenComplete(() {
          if (mounted) setState(() => _loadingMore = false);
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ctrl.setActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draft.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    await _ctrl.sendText(text);
    if (mounted &&
        ref.read(bookingChatControllerProvider(widget.bookingId)).error == null) {
      _draft.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(bookingChatControllerProvider(widget.bookingId));

    ref.listen(bookingChatControllerProvider(widget.bookingId),
        (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markReadAtBottom();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookingTitle ?? 'Nhắn tin',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            if (chat.meta != null)
              Text(
                _stateLabel(chat.meta!.state),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          if (chat.meta?.unreadCount != null && chat.meta!.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Badge(
                label: Text('${chat.meta!.unreadCount}'),
                child: const Icon(Icons.mark_chat_unread_outlined,
                    color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(chat)),
            if (chat.canSend) _buildInputBar(chat),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BookingChatState chat) {
    if (chat.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!chat.featureEnabled) {
      return const AppEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chat chưa được bật',
        message: 'Tính năng nhắn tin chưa khả dụng cho ca này.',
      );
    }
    if (!chat.canRead) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Không thể đọc tin nhắn',
        message: chat.meta?.readOnlyReason ?? '',
      );
    }
    if (chat.messages.isEmpty) {
      return const AppEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chưa có tin nhắn nào',
        message: 'Hãy bắt đầu cuộc trò chuyện!',
      );
    }

    final messages = chat.messages;
    final otherSeq = chat.meta?.otherPartyLastReadSequence ?? 0;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length + (chat.hasMoreBefore ? 1 : 0),
      itemBuilder: (context, index) {
        if (chat.hasMoreBefore && index == 0) {
          return _loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : const SizedBox.shrink();
        }
        final msgIndex = chat.hasMoreBefore ? index - 1 : index;
        final msg = messages[msgIndex];
        final showDate = msgIndex == 0 ||
            !_sameDay(messages[msgIndex - 1].createdAt, msg.createdAt);
        final readByOther = otherSeq >= msg.sequence;

        return Column(
          children: [
            if (showDate) _DateDivider(date: msg.createdAt),
            _MessageBubble(message: msg, readByOther: readByOther),
          ],
        );
      },
    );
  }

  Widget _buildInputBar(BookingChatState chat) {
    final templates = chat.meta?.quickTemplates ?? const [];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (templates.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _QuickMessageChip(
                  label: templates[i].body,
                  onTap: chat.busy
                      ? null
                      : () => _ctrl.sendQuick(templates[i]),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _draft,
                  builder: (_, val, __) => _SendButton(
                    sending: chat.busy,
                    enabled: val.text.trim().isNotEmpty,
                    onTap: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _stateLabel(String state) {
    switch (state) {
      case 'open': return 'Đang mở';
      case 'post_shift_grace': return 'Chỉ đọc (sau ca)';
      case 'read_only': return 'Chỉ đọc';
      case 'closed': return 'Đã đóng';
      default: return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = _formatDate(date.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Hôm qua';
    }
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.readByOther});
  final BookingChatMessage message;
  final bool readByOther;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _SystemMessage(body: message.body, createdAt: message.createdAt);
    }
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.senderRole != null && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    _roleLabel(message.senderRole!),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                message.body,
                style: TextStyle(
                    fontSize: 15,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                    height: 1.4),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.createdAt.toLocal()),
                    style: TextStyle(
                        fontSize: 10,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      readByOther
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: readByOther
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'CUSTOMER':
        return 'Khách hàng';
      case 'CAREGIVER':
        return 'Bạn';
      default:
        return role;
    }
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.body, required this.createdAt});
  final String body;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                DateFormat('HH:mm').format(createdAt.toLocal()),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMessageChip extends StatelessWidget {
  const _QuickMessageChip({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton(
      {required this.sending, required this.enabled, required this.onTap});
  final bool sending;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        color: enabled ? null : AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !sending ? onTap : null,
          child: Center(
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(Icons.send_rounded,
                    size: 20,
                    color: enabled ? Colors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
