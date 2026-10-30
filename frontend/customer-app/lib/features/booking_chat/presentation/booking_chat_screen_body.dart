part of 'booking_chat_screen.dart';

class _BookingChatBody extends StatelessWidget {
  const _BookingChatBody({
    required this.chat,
    required this.scrollController,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onReportMessage,
  });

  final BookingChatState chat;
  final ScrollController scrollController;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final ValueChanged<BookingChatMessage> onReportMessage;

  @override
  Widget build(BuildContext context) {
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
        subtitle: chat.meta?.readOnlyMessage ?? '',
      );
    }
    if (chat.messages.isEmpty) {
      return const _EmptyState(
        icon: Icons.waving_hand_rounded,
        title: 'Bắt đầu cuộc trò chuyện',
        subtitle: 'Gửi lời chào hoặc dùng tin nhắn nhanh bên dưới.',
      );
    }
    return _BookingChatMessageList(
      chat: chat,
      scrollController: scrollController,
      loadingMore: loadingMore,
      onLoadMore: onLoadMore,
      onReportMessage: onReportMessage,
    );
  }
}

class _BookingChatMessageList extends StatelessWidget {
  const _BookingChatMessageList({
    required this.chat,
    required this.scrollController,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onReportMessage,
  });

  final BookingChatState chat;
  final ScrollController scrollController;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final ValueChanged<BookingChatMessage> onReportMessage;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chat.messages.length + (chat.hasMoreBefore ? 1 : 0),
      itemBuilder: (context, index) {
        if (chat.hasMoreBefore && index == 0) {
          return _OlderMessagesControl(
            loading: loadingMore,
            onLoadMore: onLoadMore,
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
              onReport: message.isMine || message.isSystem
                  ? null
                  : () => onReportMessage(message),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _OlderMessagesControl extends StatelessWidget {
  const _OlderMessagesControl({
    required this.loading,
    required this.onLoadMore,
  });

  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onLoadMore,
                child: const Text('Xem tin cũ hơn'),
              ),
      ),
    );
  }
}
