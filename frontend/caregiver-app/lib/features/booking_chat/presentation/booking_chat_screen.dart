import 'dart:async';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caregiver_app/features/booking_chat/presentation/booking_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

part 'booking_chat_screen_actions.dart';
part 'booking_chat_screen_header.dart';
part 'booking_chat_screen_widgets.dart';

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

    ref.listen(bookingChatControllerProvider(widget.bookingId), (prev, next) {
      if (_mustClearDraft(prev, next)) _draft.clear();
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markReadAtBottom();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _BookingChatAppBar(
        title: widget.bookingTitle ?? 'Nhắn tin',
        status: chat.meta == null ? null : _stateLabel(chat.meta!.state),
        unreadCount: chat.meta?.unreadCount,
        blocked: chat.meta?.isBlockedByMe ?? false,
        showSafetyMenu: chat.meta?.hasChat == true,
        onReportUser: () => unawaited(_reportUser(chat)),
        onToggleBlocked: () => unawaited(
          _setBlocked(!(chat.meta?.isBlockedByMe ?? false)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(chat)),
            _buildBlockNotice(chat),
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
        message: chat.meta?.readOnlyMessage ?? '',
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
            _MessageBubble(
              message: msg,
              readByOther: readByOther,
              onReport:
                  msg.isMine || msg.isSystem ? null : () => _reportMessage(msg),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _stateLabel(String state) {
    switch (state) {
      case 'open':
        return 'Đang mở';
      case 'post_shift_grace':
        return 'Chỉ đọc (sau ca)';
      case 'read_only':
        return 'Chỉ đọc';
      case 'closed':
        return 'Đã đóng';
      default:
        return '';
    }
  }
}
