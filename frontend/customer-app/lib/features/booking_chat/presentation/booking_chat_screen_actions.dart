part of 'booking_chat_screen.dart';

extension on _BookingChatScreenState {
  Future<void> _setBlocked(bool blocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(blocked ? 'Chặn người này?' : 'Bỏ chặn người này?'),
        content: Text(blocked
            ? 'Hai bên sẽ không thể gửi tin nhắn trong cuộc trò chuyện này. Lịch sử chat, SOS và hỗ trợ CareSitter vẫn hoạt động.'
            : 'Hai bên có thể nhắn tin lại nếu cuộc trò chuyện vẫn còn hiệu lực.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(blocked ? 'Chặn' : 'Bỏ chặn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await _ctrl.setBlocked(blocked);
    if (!mounted) return;
    if (changed) {
      AppToast.success(
          context, blocked ? 'Đã chặn người này.' : 'Đã bỏ chặn người này.');
    } else {
      AppToast.error(context, 'Chưa cập nhật được. Vui lòng thử lại.');
    }
  }

  Widget _buildBlockNotice(BookingChatState chat) {
    final meta = chat.meta;
    if (meta == null || (!meta.isBlockedByMe && !meta.isBlockedByOther)) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warningLight,
      child: Row(
        children: [
          const Icon(Icons.block_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(meta.readOnlyMessage,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          if (meta.isBlockedByMe)
            TextButton(
              onPressed: chat.busy ? null : () => _setBlocked(false),
              child: const Text('Bỏ chặn'),
            ),
        ],
      ),
    );
  }

  Future<void> _reportMessage(BookingChatMessage message) async {
    final reason = await _pickReportReason(
      title: 'Báo cáo tin nhắn',
      subtitle:
          'Chọn lý do phù hợp. CareSitter sẽ lưu tin nhắn để đội an toàn xem xét.',
    );
    if (reason == null || !mounted) return;
    await _submitReport(message.id, reason);
  }

  Future<void> _reportUser(BookingChatState chat) async {
    BookingChatMessage? evidence;
    for (final message in chat.messages.reversed) {
      if (!message.isMine && !message.isSystem) {
        evidence = message;
        break;
      }
    }
    if (evidence == null) {
      AppToast.error(context,
          'Chưa có tin nhắn của người này để gửi kèm làm bằng chứng.');
      return;
    }
    final reason = await _pickReportReason(
      title: 'Báo cáo người dùng',
      subtitle:
          'CareSitter sẽ gửi thông tin người dùng và tin nhắn gần nhất của họ đến đội an toàn.',
    );
    if (reason == null || !mounted) return;
    await _submitReport(evidence.id, 'Báo cáo người dùng: $reason');
  }

  Future<String?> _pickReportReason({
    required String title,
    required String subtitle,
  }) =>
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(subtitle),
              ),
              for (final reason in const [
                'Quấy rối hoặc đe dọa',
                'Lừa đảo hoặc spam',
                'Tiết lộ thông tin riêng tư',
                'Nội dung không an toàn hoặc phản cảm',
                'Lý do khác',
              ])
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(reason),
                  onTap: () => Navigator.pop(sheetContext, reason),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  Future<void> _submitReport(String messageId, String reason) async {
    final submitted = await _ctrl.reportMessage(messageId, reason);
    if (!mounted) return;
    if (submitted) {
      AppToast.success(context, 'Đã gửi báo cáo đến đội an toàn CareSitter.');
    } else {
      AppToast.error(context, 'Chưa gửi được báo cáo. Vui lòng thử lại.');
    }
  }

  Widget _buildQuickTemplates(BookingChatState chat) {
    final templates = chat.meta?.quickTemplates ?? const [];
    if (!chat.canSend || templates.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
