import 'dart:async';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caresitter_customer/features/booking_chat/presentation/booking_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

part 'booking_chat_screen_actions.dart';
part 'booking_chat_screen_controls.dart';
part 'booking_chat_screen_messages.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BookingChatScreen extends ConsumerStatefulWidget {
  const BookingChatScreen(
      {super.key, required this.bookingId, this.bookingTitle});
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
    if (mounted &&
        ref.read(bookingChatControllerProvider(widget.bookingId)).error ==
            null) {
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

  bool _mustClearDraft(BookingChatState? previous, BookingChatState next) {
    final previousMeta = previous?.meta;
    final nextMeta = next.meta;
    if (nextMeta == null || !nextMeta.featureEnabled || !nextMeta.canRead) {
      return true;
    }
    return previousMeta != null &&
        (previousMeta.conversationId != nextMeta.conversationId ||
            previousMeta.currentEpochId != nextMeta.currentEpochId ||
            previousMeta.scopeVersion != nextMeta.scopeVersion);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(bookingChatControllerProvider(widget.bookingId));

    // Scroll to bottom khi có tin mới
    ref.listen(bookingChatControllerProvider(widget.bookingId), (prev, next) {
      if (_mustClearDraft(prev, next)) _draft.clear();
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
              _ChatStatusChip(
                  state: chat.meta!.state,
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
        subtitle:
            'Tính năng nhắn tin theo lịch đang trong giai đoạn thử nghiệm.',
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
            !_sameDay(chat.messages[msgIndex - 1].createdAt, message.createdAt);
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
