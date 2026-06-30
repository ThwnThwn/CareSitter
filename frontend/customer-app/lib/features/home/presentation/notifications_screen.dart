import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

// ─── Mock notification model ──────────────────────────────────────────────────
class _Notification {
  final String id;
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String? route; // nullable — nếu có thì navigate khi tap
  bool isRead;

  _Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.route,
    this.isRead = false,
  });
}

// ─── Static mock data ─────────────────────────────────────────────────────────
final List<_Notification> _mockNotifications = [
  _Notification(
    id: 'n001',
    title: 'Caregiver đã xác nhận lịch',
    body: 'Nguyễn Thị Lan đã xác nhận ca chăm sóc ngày 02/07 lúc 08:00.',
    time: '5 phút trước',
    icon: Icons.check_circle_outline,
    iconColor: const Color(0xFF27AE60),
    iconBg: const Color(0xFFE8F8F0),
    route: '/bookings/bk001',
  ),
  _Notification(
    id: 'n002',
    title: 'Nhắc nhở: Ca chăm sóc sắp bắt đầu',
    body: 'Ca "Đồng hành ban ngày" sẽ bắt đầu sau 1 giờ nữa.',
    time: '30 phút trước',
    icon: Icons.alarm_outlined,
    iconColor: const Color(0xFFF39C12),
    iconBg: const Color(0xFFFEF9E7),
    route: '/bookings/bk001',
  ),
  _Notification(
    id: 'n003',
    title: 'Ca chăm sóc hoàn thành',
    body: 'Ca "Đồng hành ban ngày" cho Nguyễn Văn An đã kết thúc. Hãy đánh giá dịch vụ!',
    time: '2 giờ trước',
    icon: Icons.star_outline,
    iconColor: const Color(0xFFE67E22),
    iconBg: const Color(0xFFFEF5E7),
    route: '/bookings/bk002',
  ),
  _Notification(
    id: 'n004',
    title: 'Hồ sơ người thân được cập nhật',
    body: 'Hồ sơ của Trần Thị Bình đã được cập nhật thành công.',
    time: 'Hôm qua',
    icon: Icons.person_outline,
    iconColor: const Color(0xFF2980B9),
    iconBg: const Color(0xFFEBF5FB),
    isRead: true,
  ),
  _Notification(
    id: 'n005',
    title: 'Khuyến mãi đặc biệt',
    body: 'Giảm 15% cho lần đặt lịch tiếp theo khi sử dụng mã CARE15.',
    time: '2 ngày trước',
    icon: Icons.local_offer_outlined,
    iconColor: const Color(0xFF8E44AD),
    iconBg: const Color(0xFFF4ECF7),
    isRead: true,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Bản sao local để có thể đánh dấu đã đọc
  final List<_Notification> _notifications =
      List.from(_mockNotifications);

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  void _onTap(_Notification notif) {
    setState(() => notif.isRead = true);
    if (notif.route != null) {
      context.push(notif.route!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông báo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount chưa đọc',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) =>
                  _buildItem(_notifications[index]),
            ),
    );
  }

  Widget _buildItem(_Notification notif) {
    return InkWell(
      onTap: () => _onTap(notif),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: notif.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: notif.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(notif.icon, color: notif.iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notif.time,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (notif.route != null)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 10),
                child: Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_outlined,
                color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thông báo',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Các thông báo về lịch hẹn sẽ hiển thị ở đây',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
