import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Điểm vào cấp ứng dụng cho Nutrition.
///
/// Màn hình này nằm trong `app/` vì nó ghép luồng chọn hồ sơ Beneficiary với
/// màn hình Nutrition, thay vì để hai feature phụ thuộc presentation của nhau.
class NutritionEntryScreen extends ConsumerWidget {
  const NutritionEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beneficiaries = ref.watch(beneficiaryStoreProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thực đơn dinh dưỡng')),
      body: beneficiaries.isEmpty
          ? _EmptyNutritionProfiles(
              onCreateProfile: () => context.push('/beneficiaries/create'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                const Text(
                  'Chọn người cần lập thực đơn',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.s17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.tight),
                const Text(
                  'Mỗi thực đơn được cá nhân hóa theo hồ sơ sức khỏe của từng người.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final beneficiary in beneficiaries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.tight,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            beneficiary.avatarInitial,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          beneficiary.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          beneficiary.isSelf
                              ? 'Thông tin chăm sóc của tôi'
                              : beneficiary.relation,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(
                          '/beneficiaries/${beneficiary.id}/nutrition',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _EmptyNutritionProfiles extends StatelessWidget {
  const _EmptyNutritionProfiles({required this.onCreateProfile});

  final VoidCallback onCreateProfile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 52,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Chưa có hồ sơ để lập thực đơn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Hãy tạo hồ sơ người thân trước khi sử dụng gợi ý dinh dưỡng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onCreateProfile,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Tạo hồ sơ'),
            ),
          ],
        ),
      ),
    );
  }
}
