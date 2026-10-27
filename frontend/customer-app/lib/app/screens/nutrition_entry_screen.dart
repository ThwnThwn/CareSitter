import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_load_state_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_profile_item.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_entry_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_entry_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

/// Ghép luồng chọn Beneficiary với màn hình Nutrition chi tiết.
class NutritionEntryScreen extends ConsumerWidget {
  const NutritionEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beneficiaries = ref.watch(beneficiaryStoreProvider);
    final loadState = ref.watch(beneficiaryLoadStateProvider);
    final selected = ref.watch(nutritionSelectedBeneficiaryProvider);
    final selectedId = selected.valueOrNull;
    final selectedBeneficiary = selectedId == null
        ? null
        : beneficiaries
            .where((beneficiary) => beneficiary.id == selectedId)
            .firstOrNull;
    if (selected.isLoading && beneficiaries.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Thực đơn dinh dưỡng'),
          actions: [
            IconButton(
              tooltip: 'Tra cứu tài liệu dinh dưỡng',
              onPressed: () => context.push(AppRoutes.nutritionKnowledge),
              icon: const Icon(Icons.menu_book_outlined),
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Đang mở thực đơn gần nhất',
          ),
        ),
      );
    }
    if (selectedBeneficiary != null) {
      return NutritionScreen(
        beneficiaryId: selectedBeneficiary.id,
        beneficiaryName: selectedBeneficiary.name,
        onChangeBeneficiary: () =>
            ref.read(nutritionSelectedBeneficiaryProvider.notifier).clear(),
      );
    }
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
            age: beneficiary.age,
            gender: beneficiary.gender,
            supportingText: beneficiary.condition.trim().isNotEmpty
                ? beneficiary.condition.trim()
                : 'Kiểm tra và cập nhật thông tin trước khi nhận gợi ý.',
          ),
        )
        .toList(growable: false);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thực đơn dinh dưỡng'),
        actions: [
          IconButton(
            tooltip: 'Tra cứu tài liệu dinh dưỡng',
            onPressed: () => context.push(AppRoutes.nutritionKnowledge),
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      body: NutritionEntryBody(
        profiles: profiles,
        isLoading: loadState.isLoading || selected.isLoading,
        hasError: loadState.hasError,
        onCreateProfile: () => context.push(AppRoutes.beneficiaryNew),
        onSelect: (id) =>
            ref.read(nutritionSelectedBeneficiaryProvider.notifier).select(id),
        onRetry: () => ref.read(beneficiaryStoreProvider.notifier).reload(),
      ),
    );
  }
}
