import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_detail_body.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_detail_header.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_care_level_summary.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_entry_controller.dart';

class BeneficiaryDetailScreen extends ConsumerWidget {
  final String id;
  const BeneficiaryDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beneficiaries = ref.watch(beneficiaryStoreProvider);
    final b = beneficiaries.where((x) => x.id == id).firstOrNull;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Hồ sơ người thân'),
            leading: const AppBackButton(fallbackRoute: '/beneficiaries')),
        body: const Center(child: Text('Không tìm thấy hồ sơ người thân.')),
      );
    }
    final careLevelColor = b.careLevel == 'Nặng'
        ? AppColors.error
        : b.careLevel == 'Trung bình'
            ? AppColors.warning
            : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          BeneficiaryDetailHeader(b: b),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  if (ref.watch(nutritionEntryProvider).value == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant_menu,
                            color: AppColors.primary),
                        title: const Text('Gợi ý thực đơn'),
                        subtitle: const Text(
                            'Kiểm tra thông tin sức khỏe và chọn món'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/beneficiaries/${b.id}/nutrition'),
                      ),
                    ),
                  // Mức chăm sóc
                  BeneficiaryCareLevelSummary(
                      careLevelColor: careLevelColor, b: b),
                  const SizedBox(height: AppSpacing.compact),
                  _buildCard('📋 Nhu cầu hỗ trợ / Lưu ý', b.conditionLabel),
                  const SizedBox(height: AppSpacing.compact),
                  _buildCard('📝 Ghi chú', b.notes),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/booking/new?beneficiaryId=${b.id}'),
                      icon: const Icon(Icons.add),
                      label: Text('Đặt lịch cho ${b.name}'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Liên hệ khẩn cấp (FR-CUS-04) ──────────────
                  if (b.emergencyContacts.isNotEmpty) ...[
                    BeneficiaryDetailBody(b: b),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.tight),
          Text(content,
              style: const TextStyle(
                  fontSize: AppFontSizes.s14,
                  color: AppColors.textSecondary,
                  height: 1.5)),
        ],
      ),
    );
  }
}
