import 'package:caregiver_app/features/settings/presentation/widgets/document_status_tile.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/document_status_overall_status.dart';
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallStatus(statusText, status == 'APPROVED'),
            const SizedBox(height: AppSpacing.lg),
            if (profile.requiresSecureResubmission) ...[
              const Text(
                  'Tài liệu cũ cần chuyển sang lưu trữ riêng tư. Nếu hồ sơ đang chờ duyệt hoặc đã duyệt, hãy liên hệ hỗ trợ để được hướng dẫn nộp lại.'),
              const SizedBox(height: AppSpacing.md),
            ],
            if (profile.cccdFrontMediaId == null &&
                profile.cccdBackMediaId == null)
              const AppEmptyState(
                icon: Icons.description_outlined,
                title: 'Chưa nộp tài liệu',
                message: 'Bạn cần nộp đủ hai mặt CCCD để bắt đầu xác minh.',
              )
            else ...[
              _documentTile('Mặt trước CCCD', profile.cccdFrontMediaId),
              const SizedBox(height: AppSpacing.compact),
              _documentTile('Mặt sau CCCD', profile.cccdBackMediaId),
              ...profile.certificateMediaIds.indexed.map((entry) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.compact),
                    child: _documentTile('Chứng chỉ ${entry.$1 + 1}', entry.$2),
                  )),
            ],
            if (status == 'DRAFT' || status == 'REJECTED') ...[
              const SizedBox(height: AppSpacing.lg),
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

  Widget _documentTile(String title, String? url) =>
      DocumentStatusTile(url: url, title: title);

  Widget _buildOverallStatus(String statusText, bool approved) =>
      DocumentStatusOverallStatus(approved: approved, statusText: statusText);
}
