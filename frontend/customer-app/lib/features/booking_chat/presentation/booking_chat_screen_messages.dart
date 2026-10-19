part of 'booking_chat_screen.dart';

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
  Widget build(BuildContext context) => _content(context);

  Widget _content(BuildContext context) {
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
                      readByOther ? Icons.done_all_rounded : Icons.done_rounded,
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
