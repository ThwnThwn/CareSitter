import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';

class DocumentStatusScreen extends StatelessWidget {
  const DocumentStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            _buildOverallStatus(),
            const SizedBox(height: 24),
            const Text(
              'Tài liệu bắt buộc',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _buildDocumentItem(
              context: context,
              title: 'Căn cước công dân (CCCD)',
              status: 'approved',
              updatedAt: '10/05/2026',
            ),
            _buildDocumentItem(
              context: context,
              title: 'Ảnh chân dung',
              status: 'approved',
              updatedAt: '10/05/2026',
            ),
            _buildDocumentItem(
              context: context,
              title: 'Giấy khám sức khỏe',
              status: 'expiring',
              updatedAt: '01/01/2026',
              note: 'Hết hạn vào 01/07/2026 (còn 3 ngày)',
            ),
            const SizedBox(height: 24),
            const Text(
              'Chứng chỉ liên quan (Tùy chọn)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _buildDocumentItem(
              context: context,
              title: 'Chứng chỉ sơ cấp cứu',
              status: 'pending',
              updatedAt: '25/06/2026',
            ),
            _buildDocumentItem(
              context: context,
              title: 'Bằng điều dưỡng',
              status: 'missing',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hồ sơ đã duyệt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn đủ điều kiện nhận ca. Vui lòng cập nhật các giấy tờ sắp hết hạn.',
                  style: TextStyle(fontSize: 13, color: AppColors.primary.withValues(alpha: 0.8)),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                ],
                if (updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Cập nhật: $updatedAt', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => context.push('/settings/documents/upload', extra: title),
          ),
        ],
      ),
    );
  }
}
