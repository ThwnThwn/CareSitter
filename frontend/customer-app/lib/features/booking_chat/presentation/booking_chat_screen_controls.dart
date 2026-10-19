part of 'booking_chat_screen.dart';

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
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
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
            Icon(icon,
                size: 52, color: AppColors.primary.withValues(alpha: 0.4)),
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
