import 'dart:async';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caresitter_customer/features/booking_chat/presentation/booking_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

part 'booking_chat_screen_actions.dart';
part 'booking_chat_screen_body.dart';
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
        _loadMore();
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

  void _loadMore() {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    _ctrl.loadMore().whenComplete(() {
      if (mounted) setState(() => _loadingMore = false);
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
      appBar: _BookingChatAppBar(
        title: widget.bookingTitle ?? 'Nhắn tin',
        meta: chat.meta,
        onRefresh: _ctrl.refresh,
        onReportUser: () => unawaited(_reportUser(chat)),
        onToggleBlocked: () => unawaited(
          _setBlocked(!(chat.meta?.isBlockedByMe ?? false)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _BookingChatBody(
                chat: chat,
                scrollController: _scrollController,
                loadingMore: _loadingMore,
                onLoadMore: _loadMore,
                onReportMessage: _reportMessage,
              ),
            ),
            if (chat.error != null)
              _ErrorBanner(
                message: chat.error!,
                onDismiss: () => _ctrl.refresh(),
              ),
            _buildBlockNotice(chat),
            _buildQuickTemplates(chat),
            _buildInputBar(chat),
          ],
        ),
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
                    : chat.meta?.readOnlyMessage.isNotEmpty == true
                        ? chat.meta!.readOnlyMessage
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
}
