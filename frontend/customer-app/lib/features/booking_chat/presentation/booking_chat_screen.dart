import 'dart:async';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caresitter_customer/features/booking_chat/presentation/booking_chat_controller.dart';
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
      // Load more khi scroll đến đầu (extentBefore nhỏ)
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
    if (mounted && ref.read(bookingChatControllerProvider(widget.bookingId)).error == null) {
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

    // Scroll to bottom khi có tin mới
    ref.listen(bookingChatControllerProvider(widget.bookingId),
        (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _markReadAtBottom();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookingTitle ?? 'Nhắn tin',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            if (chat.meta != null)
              _ChatStatusChip(state: chat.meta!.state,
                  writeClosesAt: chat.meta!.writeClosesAt),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => _ctrl.refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(chat)),
            if (chat.error != null)
              _ErrorBanner(
                message: chat.error!,
                onDismiss: () => _ctrl.refresh(),
              ),
            _buildQuickTemplates(chat),
            _buildInputBar(chat),
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
      return const _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chat chưa được bật',
        subtitle: 'Tính năng nhắn tin theo lịch đang trong giai đoạn thử nghiệm.',
      );
    }
    if (!chat.canRead && chat.meta?.state == 'unavailable') {
      return const _EmptyState(
        icon: Icons.hourglass_top_rounded,
        title: 'Chat sẽ mở sau khi caregiver nhận lịch',
        subtitle: 'Bạn có thể nhắn tin ngay khi caregiver xác nhận lịch hẹn.',
      );
    }
    if (!chat.canRead) {
      return _EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Chat đã kết thúc',
        subtitle: chat.meta?.readOnlyReason ?? '',
      );
    }
    if (chat.messages.isEmpty) {
      return const _EmptyState(
        icon: Icons.waving_hand_rounded,
        title: 'Bắt đầu cuộc trò chuyện',
        subtitle: 'Gửi lời chào hoặc dùng tin nhắn nhanh bên dưới.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chat.messages.length + (chat.hasMoreBefore ? 1 : 0),
      itemBuilder: (context, index) {
        if (chat.hasMoreBefore && index == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _loadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () {
                        if (_loadingMore) return;
                        _loadingMore = true;
                        _ctrl.loadMore().whenComplete(() {
                          if (mounted) setState(() => _loadingMore = false);
                        });
                      },
                      child: const Text('Xem tin cũ hơn'),
                    ),
            ),
          );
        }
        final msgIndex = chat.hasMoreBefore ? index - 1 : index;
        final message = chat.messages[msgIndex];
        final showDateDivider = msgIndex == 0 ||
            !_sameDay(
                chat.messages[msgIndex - 1].createdAt, message.createdAt);
        return Column(
          children: [
            if (showDateDivider) _DateDivider(date: message.createdAt),
            _MessageBubble(
              message: message,
              readByOther: message.isMine &&
                  message.sequence <=
                      (chat.meta?.otherPartyLastReadSequence ?? 0),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickTemplates(BookingChatState chat) {
    final templates = chat.meta?.quickTemplates ?? const [];
    if (!chat.canSend || templates.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = templates[i];
          return _QuickMessageChip(
            label: t.body,
            onTap: chat.busy
                ? null
                : () => _ctrl.sendQuick(t).then((_) {
                      if (mounted) {
                        final err = ref
                            .read(bookingChatControllerProvider(widget.bookingId))
                            .error;
                        if (err != null) AppToast.error(context, err);
                      }
                    }),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(BookingChatState chat) {
    final canSend = chat.canSend;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _draft,
              enabled: canSend,
              maxLines: 4,
              minLines: 1,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                counterText: '',
                hintText: canSend
                    ? 'Nhập tin nhắn…'
                    : chat.meta?.readOnlyReason.isNotEmpty == true
                        ? chat.meta!.readOnlyReason
                        : 'Chat đã đóng',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: canSend
                    ? AppColors.primaryContainer.withValues(alpha: 0.5)
                    : AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            sending: chat.busy,
            enabled: canSend,
            onTap: _send,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ChatStatusChip extends StatelessWidget {
  const _ChatStatusChip({required this.state, this.writeClosesAt});
  final String state;
  final DateTime? writeClosesAt;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (state) {
      case 'open':
        color = AppColors.primary;
        label = 'Đang hoạt động';
      case 'post_shift_grace':
        color = AppColors.amber;
        final closes = writeClosesAt;
        label = closes != null
            ? 'Kết thúc ${DateFormat('HH:mm dd/MM').format(closes.toLocal())}'
            : 'Sau ca – sắp đóng';
      case 'read_only':
        color = AppColors.textSecondary;
        label = 'Chỉ đọc';
      case 'purged':
        color = AppColors.textSecondary;
        label = 'Đã xóa';
      default:
        color = AppColors.textSecondary;
        label = 'Chờ caregiver nhận';
    }
    return Text(
      label,
      style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.legacyErrorLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.legacyError, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.legacyError)),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
              color: AppColors.legacyError,
            ),
          ],
        ),
      ),
    );
  }
}

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
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
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
        return 'Bạn';
      case 'CAREGIVER':
        return 'Người chăm sóc';
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
