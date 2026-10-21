import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Composition root cho màn Nutrition của một Beneficiary cụ thể.
class NutritionDetailEntryScreen extends ConsumerWidget {
  const NutritionDetailEntryScreen({
    super.key,
    required this.beneficiaryId,
  });

  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref
        .watch(beneficiaryStoreProvider)
        .where((beneficiary) => beneficiary.id == beneficiaryId)
        .firstOrNull
        ?.name;
    return NutritionScreen(
      beneficiaryId: beneficiaryId,
      beneficiaryName: name,
    );
  }
}
