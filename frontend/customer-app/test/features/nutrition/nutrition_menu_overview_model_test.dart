import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_flow_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_menu_overview_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved menu exposes totals and saved copy', () {
    final overview = NutritionMenuOverviewModel.fromFlow(
      _flow(
        status: 'saved',
        state: 'suggested',
        meals: const [
          {
            'mealType': 'breakfast',
            'name': 'Bữa sáng',
            'nutrients': {'energy_kcal': 320},
          },
          {
            'mealType': 'lunch',
            'name': 'Bữa trưa',
            'nutrients': {'energy_kcal': 540},
          },
        ],
      ),
    );

    expect(overview.title, 'Thực đơn ngày 22/10');
    expect(overview.badgeLabel, 'Đã lưu');
    expect(overview.totalKcal, 860);
    expect(overview.tone, NutritionMenuOverviewTone.success);
  });

  test('workflow states are not presented as a menu being generated', () {
    final stale = NutritionMenuOverviewModel.fromFlow(
      _flow(status: 'stale', state: 'suggested'),
    );
    final failed = NutritionMenuOverviewModel.fromFlow(
      _flow(status: 'failed', state: 'failed'),
    );

    expect(stale.title, 'Tổng quan dinh dưỡng');
    expect(stale.badgeLabel, 'Cần kiểm tra');
    expect(stale.tone, NutritionMenuOverviewTone.warning);
    expect(failed.badgeLabel, 'Có lỗi');
    expect(failed.tone, NutritionMenuOverviewTone.error);
  });

  test('stale menus do not advertise invalidated meals or nutrition totals',
      () {
    final overview = NutritionMenuOverviewModel.fromFlow(_flow(
      status: 'stale',
      state: 'suggested',
      meals: const [
        {
          'name': 'Món cũ',
          'nutrients': {'energy_kcal': 500}
        },
      ],
    ));

    expect(overview.hasMeals, isFalse);
    expect(overview.mealCount, 0);
    expect(overview.totalKcal, 0);
    expect(overview.badgeLabel, 'Cần kiểm tra');
  });
}

NutritionFlow _flow({
  required String status,
  required String state,
  List<Map<String, dynamic>> meals = const [],
}) =>
    NutritionFlow(
      resource: NutritionResourceModel.fromJson({
        'status': status,
        'data': {
          'plannedDate': '2026-10-22',
          'decision': {'state': state},
          'meals': meals,
        },
      }),
    );
