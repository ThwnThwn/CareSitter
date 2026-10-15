import 'package:caresitter_customer/features/settings/presentation/widgets/support_panel.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Liên hệ hỗ trợ'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SupportPanel(),
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.compact),
            child: Text(
              'Các kênh hỗ trợ',
              style: TextStyle(
                  fontSize: AppFontSizes.s16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
          _buildContactCard(
            icon: Icons.chat_bubble_outline,
            title: 'Chat trực tuyến',
            subtitle: 'Gửi yêu cầu và theo dõi phản hồi trong ứng dụng',
            actionText: 'Bắt đầu chat',
            onTap: () => context.push('/settings/support/chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.compact),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppFontSizes.s15,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: AppFontSizes.s13,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(
              actionText,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSizes.s13),
            ),
          ],
        ),
      ),
    );
  }
}
