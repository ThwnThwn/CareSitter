import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/presentation/providers/profile_provider.dart';

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
            const AppEmptyState(
              icon: Icons.description_outlined,
              title: 'Chưa có danh sách tài liệu',
              message:
                  'Thông tin từng tài liệu sẽ hiển thị sau khi backend cung cấp dữ liệu hồ sơ.',
            ),
          ],
        ),
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
                  style: TextStyle(
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

  Widget _buildDocumentItem({
    required BuildContext context,
    required String title,
    required String status,
    String? updatedAt,
    String? note,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF27AE60);
        statusText = 'Đã duyệt';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = const Color(0xFFF2994A);
        statusText = 'Chờ duyệt';
        statusIcon = Icons.access_time_filled;
        break;
      case 'expiring':
        statusColor = AppColors.error;
        statusText = 'Sắp hết hạn';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'missing':
      default:
        statusColor = AppColors.textHint;
        statusText = 'Chưa nộp';
        statusIcon = Icons.upload_file_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error)),
                ],
                if (updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Cập nhật: $updatedAt',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () =>
                context.push('/settings/documents/upload', extra: title),
          ),
        ],
      ),
    );
  }
}
