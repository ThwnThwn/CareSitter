import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../models/nutrition_flow_model.dart';

class NutritionEmptyState extends StatelessWidget {
  const NutritionEmptyState(
      {super.key, required this.flow, required this.onReload});
  final NutritionFlow flow;
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: flow.loading
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(flow.error ?? 'Hồ sơ không còn khả dụng.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                      onPressed: onReload, child: const Text('Tải lại'))
                ])));
}
