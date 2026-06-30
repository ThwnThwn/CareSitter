import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_data.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildProfileCard(context),
                const SizedBox(height: 20),
                _buildSection('Tài khoản', [
                  _SettingsItem(
                    icon: Icons.person_outline,
                    title: 'Thông tin cá nhân',
                    subtitle: 'Tên, số điện thoại, địa chỉ',
                    onTap: () => context.push('/settings/profile/edit'),
                  ),
                  _SettingsItem(
                    icon: Icons.credit_card_outlined,
                    title: 'Phương thức thanh toán',
                    subtitle: 'Thẻ, ví điện tử, chuyển khoản',
                    onTap: () => context.push('/settings/payment'),
                  ),
                  _SettingsItem(
                    icon: Icons.location_on_outlined,
                    title: 'Địa chỉ đã lưu',
                    subtitle: '3 địa chỉ',
                    onTap: () => context.push('/settings/addresses'),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Thông báo', [
                  _SettingsToggleItem(
                    icon: Icons.notifications_outlined,
                    title: 'Thông báo đẩy',
                    subtitle: 'Nhận thông báo từ app',
                    value: true,
                    onChanged: (v) {},
                  ),
                  _SettingsToggleItem(
                    icon: Icons.sms_outlined,
                    title: 'Thông báo SMS',
                    subtitle: 'Nhắc lịch hẹn qua tin nhắn',
                    value: true,
                    onChanged: (v) {},
                  ),
                  _SettingsToggleItem(
                    icon: Icons.email_outlined,
                    title: 'Thông báo Email',
                    subtitle: 'Xác nhận, hoá đơn qua email',
                    value: false,
                    onChanged: (v) {},
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Quyền riêng tư & Bảo mật', [
                  _SettingsItem(
                    icon: Icons.lock_outline,
                    title: 'Đổi mật khẩu',
                    onTap: () => context.push('/settings/password'),
                  ),
                  _SettingsItem(
                    icon: Icons.security_outlined,
                    title: 'Xác thực 2 lớp',
                    subtitle: 'Bảo vệ tài khoản',
                    onTap: () => context.push('/settings/2fa'),
                  ),
                  _SettingsItem(
                    icon: Icons.policy_outlined,
                    title: 'Quyền riêng tư',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                '📜 Điều khoản riêng tư CareSitter v1.1'))),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Hỗ trợ', [
                  _SettingsItem(
                    icon: Icons.help_outline,
                    title: 'Câu hỏi thường gặp',
                    onTap: () => context.push('/settings/faq'),
                  ),
                  _SettingsItem(
                    icon: Icons.headset_mic_outlined,
                    title: 'Liên hệ hỗ trợ',
                    subtitle: 'Hotline: 1800 6789',
                    onTap: () => context.push('/settings/support'),
                  ),
                  _SettingsItem(
                    icon: Icons.star_border_outlined,
                    title: 'Đánh giá ứng dụng',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                '⭐ Cảm ơn bạn đã đánh giá 5 sao cho CareSitter!'))),
                  ),
                  _SettingsItem(
                    icon: Icons.info_outline,
                    title: 'Về CareSitter',
                    subtitle: 'Phiên bản 1.1.0',
                    onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'CareSitter Customer',
                        applicationVersion: '1.1.0'),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildLogoutButton(context),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return const SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x1A2F7F7F),
      title: Text(
        'Cài đặt',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.elevated,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                MockData.currentUserAvatar,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  MockData.currentUserName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MockData.currentUserPhone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✅ Đã xác thực',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/settings/profile/edit'),
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout, color: AppColors.error, size: 20),
        ),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.error),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Đăng xuất'),
              content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/auth/phone');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(80, 40),
                  ),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                )
              : null,
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textHint, size: 20),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 56, color: AppColors.divider),
      ],
    );
  }
}

class _SettingsToggleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                )
              : null,
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ),
        const Divider(height: 1, indent: 56, color: AppColors.divider),
      ],
    );
  }
}
