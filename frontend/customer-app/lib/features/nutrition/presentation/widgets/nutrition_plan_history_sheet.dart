import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:flutter/material.dart';

class NutritionPlanHistorySheet extends StatelessWidget {
  const NutritionPlanHistorySheet({super.key, required this.plans});

  final List<MealPlanSummaryModel> plans;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: plans.isEmpty
              ? const Center(child: Text('Chưa có thực đơn đã lưu.'))
              : ListView(
                  children: [
                    const ListTile(title: Text('Thực đơn đã lưu gần đây')),
                    for (final plan in plans)
                      ListTile(
                        title: Text('Ngày ${plan.plannedDate}'),
                        subtitle: Text(
                          plan.status == 'stale'
                              ? 'Cần kiểm tra lại thông tin'
                              : 'Đã lưu',
                        ),
                        onTap: () => Navigator.pop(context, plan.id),
                      ),
                  ],
                ),
        ),
      );
}
