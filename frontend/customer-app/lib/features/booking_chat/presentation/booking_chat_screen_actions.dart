part of 'booking_chat_screen.dart';

extension on _BookingChatScreenState {
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
                      if (context.mounted) {
                        final err = ref
                            .read(
                                bookingChatControllerProvider(widget.bookingId))
                            .error;
                        if (err != null) {
                          AppToast.error(context, err);
                        }
                      }
                    }),
          );
        },
      ),
    );
  }
}
