import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/data/caregiver_profile_model.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/presentation/providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileCard(context, profile),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Cài đặt hồ sơ',
              items: [
                _SettingsItem(
                  icon: Icons.person_outline,
                  title: 'Thông tin cá nhân',
                  onTap: () => context.push('/settings/profile/edit'),
                ),
                _SettingsItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Thu nhập & ví',
                  subtitle: 'Xem số dư, lịch sử và yêu cầu rút tiền',
                  onTap: () => context.push('/earnings'),
                ),
                _SettingsItem(
                  icon: Icons.badge_outlined,
                  title: 'Hồ sơ & Giấy tờ',
                  subtitle: 'Đã duyệt • Còn hạn',
                  onTap: () => context.push('/settings/documents'),
                ),
                _SettingsItem(
                  icon: Icons.star_outline_rounded,
                  title: 'Đánh giá & Nhận xét',
                  onTap: () => context.push('/settings/reviews'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Hỗ trợ',
              items: [
                _SettingsItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Câu hỏi thường gặp',
                  onTap: () => context.push('/settings/faq'),
                ),
                _SettingsItem(
                  icon: Icons.support_agent_rounded,
                  title: 'Trung tâm trợ giúp',
                  onTap: () => context.push('/settings/support'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Đăng xuất',
                icon: Icons.logout_rounded,
                backgroundColor: AppColors.errorLight,
                foregroundColor: AppColors.error,
                onPressed: () async {
                  await ref.read(authRepositoryProvider).logout();
                  if (context.mounted) context.go('/auth/phone');
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'CareSitter Caregiver v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context, CaregiverProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage: profile.avatarUrl != null &&
                    profile.avatarUrl!.isNotEmpty
                ? ResizeImage(CachedNetworkImageProvider(profile.avatarUrl!),
                    width: 192)
                : null,
            child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                ? Text(
                    profile.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.locationText == 'Chưa cập nhật'
                      ? _shortIdLabel(profile.id)
                      : profile.locationText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => context.push('/settings/profile/edit'),
          ),
        ],
      ),
    );
  }

  String _shortIdLabel(String id) {
    if (id.isEmpty) return 'Chưa có hồ sơ caregiver';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return 'ID hồ sơ: $shortId';
  }

  Widget _buildSection(
      {required String title, required List<_SettingsItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading:
                          Icon(e.value.icon, color: AppColors.textSecondary),
                      title: Text(
                        e.value.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: e.value.subtitle != null
                          ? Text(e.value.subtitle!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.primary))
                          : null,
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textHint),
                      onTap: e.value.onTap,
                    ),
                    if (!isLast) const Divider(height: 1, indent: 56),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
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
}
