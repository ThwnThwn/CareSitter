import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class DocumentStatusScreen extends ConsumerWidget {
  const DocumentStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final status = profile.kycStatus.toUpperCase();
    final statusText = switch (status) {
      'APPROVED' => 'Hồ sơ đã được duyệt',
      'PENDING' => 'Hồ sơ đang chờ duyệt',
      'REJECTED' => 'Hồ sơ cần được cập nhật',
      'SUSPENDED' => 'Hồ sơ đang bị tạm ngưng',
      _ => 'Chưa có dữ liệu hồ sơ',
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ & Giấy tờ'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallStatus(statusText, status == 'APPROVED'),
            const SizedBox(height: 24),
            if (profile.cccdFrontUrl == null && profile.cccdBackUrl == null)
              const AppEmptyState(
                icon: Icons.description_outlined,
                title: 'Chưa nộp tài liệu',
                message: 'Bạn cần nộp đủ hai mặt CCCD để bắt đầu xác minh.',
              )
            else ...[
              _documentTile('Mặt trước CCCD', profile.cccdFrontUrl),
              const SizedBox(height: 12),
              _documentTile('Mặt sau CCCD', profile.cccdBackUrl),
              ...profile.certificateUrls.indexed.map((entry) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _documentTile('Chứng chỉ ${entry.$1 + 1}', entry.$2),
                  )),
            ],
            if (status == 'DRAFT' || status == 'REJECTED') ...[
              const SizedBox(height: 24),
              AppButton(
                label: status == 'REJECTED' ? 'Nộp lại hồ sơ' : 'Nộp hồ sơ KYC',
                icon: Icons.upload_file_rounded,
                onPressed: () => context.push('/settings/documents/upload'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _documentTile(String title, String? url) {
    final available = url != null && url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: available ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            available ? 'Đã tải lên' : 'Còn thiếu',
            style: TextStyle(
              color: available ? AppColors.success : AppColors.warning,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatus(String statusText, bool approved) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          Icon(
              approved
                  ? Icons.verified_user_rounded
                  : Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  approved
                      ? 'Bạn đủ điều kiện nhận ca theo trạng thái từ hệ thống.'
                      : 'Hãy cập nhật hồ sơ khi backend cung cấp yêu cầu bổ sung.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
