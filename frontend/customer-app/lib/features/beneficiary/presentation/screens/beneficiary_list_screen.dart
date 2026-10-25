import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_list_app_bar.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_list_groups.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_list_card_summary.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:caresitter_customer/core/widgets/app_avatar_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryListScreen extends ConsumerWidget {
  const BeneficiaryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beneficiaries = ref.watch(beneficiaryStoreProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BeneficiaryListAppBar(beneficiaries: beneficiaries),
      body: beneficiaries.isEmpty
          ? _buildEmptyState(context)
          : BeneficiaryListGroups(
              beneficiaries: beneficiaries,
              buildBeneficiaryCard: _buildBeneficiaryCard),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            const Text(
              'Chưa có hồ sơ người thân',
              style: TextStyle(
                fontSize: AppFontSizes.s17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Hãy thêm hồ sơ người thân để đặt lịch\nchăm sóc chu đáo nhất.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.s13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.beneficiaryNew),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm người thân ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.compact),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Beneficiary Card ─────────────────────────────────────────────────────
  Widget _buildBeneficiaryCard(BeneficiaryModel b, BuildContext context) {
    final careColor = b.careLevel == 'Nặng'
        ? AppColors.legacyError
        : b.careLevel == 'Trung bình'
            ? AppColors.warning
            : AppColors.success;
    final hasAvatar = b.avatarPath?.trim().isNotEmpty == true;
    final defaultAvatarPath = defaultAvatarAssetForGender(
      age: b.age,
      gender: b.gender,
    );

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => context.push(AppRoutes.beneficiaryDetail(b.id)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.inset, vertical: AppSpacing.inset),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // ── Avatar ──
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryContainer,
                  backgroundImage: hasAvatar
                      ? appAvatarImageProvider(b.avatarPath!)
                      : defaultAvatarPath == null
                          ? null
                          : AssetImage(defaultAvatarPath),
                  onBackgroundImageError: hasAvatar || defaultAvatarPath != null
                      ? (_, __) {}
                      : null,
                  child: !hasAvatar && defaultAvatarPath == null
                      ? const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.compact),

              // ── Info ──
              BeneficiaryListCardSummary(b: b, careColor: careColor),
              const SizedBox(width: AppSpacing.sm),

              // ── Chevron ──
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
