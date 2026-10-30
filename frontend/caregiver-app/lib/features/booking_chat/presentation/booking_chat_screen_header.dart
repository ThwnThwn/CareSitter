part of 'booking_chat_screen.dart';

class _BookingChatAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BookingChatAppBar({
    required this.title,
    required this.status,
    required this.unreadCount,
    required this.blocked,
    required this.showSafetyMenu,
    required this.onReportUser,
    required this.onToggleBlocked,
  });

  final String title;
  final String? status;
  final int? unreadCount;
  final bool blocked;
  final bool showSafetyMenu;
  final VoidCallback onReportUser;
  final VoidCallback onToggleBlocked;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleSpacing: 0,
      leading: const BackButton(color: AppColors.textPrimary),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (status != null)
            Text(
              status!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      actions: [
        if (unreadCount != null && unreadCount! > 0)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Badge(
              label: Text('$unreadCount'),
              child: const Icon(
                Icons.mark_chat_unread_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
        if (showSafetyMenu)
          _BookingChatSafetyMenu(
            blocked: blocked,
            onReportUser: onReportUser,
            onToggleBlocked: onToggleBlocked,
          ),
      ],
    );
  }
}

class _BookingChatSafetyMenu extends StatelessWidget {
  const _BookingChatSafetyMenu({
    required this.blocked,
    required this.onReportUser,
    required this.onToggleBlocked,
  });

  final bool blocked;
  final VoidCallback onReportUser;
  final VoidCallback onToggleBlocked;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tùy chọn an toàn',
      onSelected: (action) =>
          action == 'report_user' ? onReportUser() : onToggleBlocked(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report_user',
          child: Row(
            children: [
              Icon(Icons.report_outlined),
              SizedBox(width: 12),
              Text('Báo cáo người dùng'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle_block',
          child: Row(
            children: [
              Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded),
              const SizedBox(width: 12),
              Text(blocked ? 'Bỏ chặn người này' : 'Chặn người này'),
            ],
          ),
        ),
      ],
    );
  }
}
