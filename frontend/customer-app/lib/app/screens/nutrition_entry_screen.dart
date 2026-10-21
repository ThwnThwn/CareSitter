import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_load_state_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_profile_item.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_entry_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ghép luồng chọn Beneficiary với màn hình Nutrition chi tiết.
class NutritionEntryScreen extends ConsumerWidget {
  const NutritionEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beneficiaries = ref.watch(beneficiaryStoreProvider);
    final loadState = ref.watch(beneficiaryLoadStateProvider);
    final profiles = beneficiaries
        .map(
          (beneficiary) => NutritionProfileItem(
            id: beneficiary.id,
            name: beneficiary.name,
            relationshipLabel:
                beneficiary.isSelf ? 'Hồ sơ của tôi' : beneficiary.relation,
            ageLabel: beneficiary.ageLabel,
            avatarInitial: beneficiary.avatarInitial,
            avatarPath: beneficiary.avatarPath,
            supportingText: beneficiary.condition.trim().isNotEmpty
                ? beneficiary.condition.trim()
                : 'Kiểm tra và cập nhật thông tin trước khi nhận gợi ý.',
          ),
        )
        .toList(growable: false);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thực đơn dinh dưỡng')),
      body: NutritionEntryBody(
        profiles: profiles,
        isLoading: loadState.isLoading,
        hasError: loadState.hasError,
        onCreateProfile: () => context.push('/beneficiaries/create'),
        onSelect: (id) => context.push('/beneficiaries/$id/nutrition'),
        onRetry: () => ref.read(beneficiaryStoreProvider.notifier).reload(),
      ),
    );
  }
}
