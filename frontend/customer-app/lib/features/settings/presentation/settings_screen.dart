import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/widgets/fade_slide_staggered.dart';
import '../../auth/data/auth_repository.dart';
import '../application/profile_store.dart';
import '../../booking/application/booking_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final profile = ref.watch(profileStoreProvider);
    final bookings = ref.watch(bookingStoreProvider);
    final totalSpent = bookings
        .where((b) => b.status == 'completed')
        .fold(0.0, (sum, b) => sum + b.totalPrice);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildFlatHeader(context, ref, topPadding),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Profile card
                FadeSlideStaggered(
                  index: 0,
                  child: _buildProfileCard(
                      context, ref, profile, bookings.length, totalSpent),
                ),
                const SizedBox(height: 20),

                // Beneficiaries section
                FadeSlideStaggered(
                  index: 1,
                  child: _buildBeneficiariesSection(context, ref),
                ),
                const SizedBox(height: 20),

                // Settings
                FadeSlideStaggered(
                  index: 2,
                  child: _buildSection('Tài khoản', [
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
                ),
                const SizedBox(height: 16),
                FadeSlideStaggered(
                  index: 3,
                  child: _buildSection('Bảo mật', [
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
                  ]),
                ),
                const SizedBox(height: 16),
                FadeSlideStaggered(
                  index: 4,
                  child: _buildSection('Hỗ trợ', [
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
                  ]),
                ),
                const SizedBox(height: 24),

                // Logout button
                FadeSlideStaggered(
                  index: 5,
                  child: _buildLogoutButton(context, ref),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatHeader(
      BuildContext context, WidgetRef ref, double topPadding) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: topPadding + 16, left: 20, right: 16, bottom: 14),
      child: Row(
        children: [
          const Expanded(
              child: Text('Hồ sơ của tôi',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800))),
          GestureDetector(
            onTap: () => context.push('/settings/profile/edit'),
            child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.background, shape: BoxShape.circle),
                child: const Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary, size: 22)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref,
      UserProfile profile, int bookingCount, double totalSpent) {
    final hasAvatar =
        profile.avatarPath != null && profile.avatarPath!.isNotEmpty;
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .map((String p) => p[0].toUpperCase())
        .take(2)
        .join();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card),
      child: Column(
        children: [
          Stack(children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: hasAvatar
                  ? (kIsWeb
                      ? NetworkImage(profile.avatarPath!)
                      : FileImage(File(profile.avatarPath!))) as ImageProvider
                  : null,
              child: hasAvatar
                  ? null
                  : Text(initials.isNotEmpty ? initials : 'U',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => context.push('/settings/profile/edit'),
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(profile.name.isNotEmpty ? profile.name : 'Người dùng',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              [
                if (profile.phone.isNotEmpty) profile.phone,
                if (profile.email.isNotEmpty) profile.email
              ].join(' - '),
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$bookingCount lịch hẹn',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Text('  -  ',
                style: TextStyle(
                    color: AppColors.textHint, fontWeight: FontWeight.w700)),
            Text(_formatCurrency(totalSpent),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/settings/profile/edit'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Chỉnh sửa hồ sơ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiariesSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.directions_walk_rounded,
              color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Text('Người thân được chăm sóc',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/beneficiaries'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 22)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Xem danh sách người thân',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text('Quản lý hồ sơ cần chăm sóc',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ])),
              const Icon(Icons.chevron_right,
                  color: AppColors.textHint, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push('/beneficiaries/create'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x662D9E6B), width: 1.5)),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Thêm người thân mới',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]),
            child: Column(children: items),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Đăng xuất'),
              content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(authRepositoryProvider).logout();
                    if (context.mounted) context.go('/auth/login');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size(80, 40)),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout_rounded,
            color: Color(0xFFE74C3C), size: 18),
        label: const Text('Đăng xuất',
            style: TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE74C3C), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final s = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$sđ đã chi';
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _SettingsItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textHint, size: 20),
        onTap: onTap,
      ),
      const Divider(height: 1, indent: 56, color: AppColors.divider),
    ]);
  }
}
