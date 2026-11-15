import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/booking_meals_model.dart';
import '../controllers/booking_meal_options_provider.dart';
import '../models/booking_meal_copy.dart';

class BookingMealShareOptions extends ConsumerStatefulWidget {
  const BookingMealShareOptions({
    super.key,
    required this.data,
    required this.window,
    required this.disabled,
    required this.onSelect,
  });

  final BookingMealsModel data;
  final BookingMealShareWindow window;
  final bool disabled;
  final ValueChanged<MealPlanSummaryModel> onSelect;

  @override
  ConsumerState<BookingMealShareOptions> createState() =>
      _BookingMealShareOptionsState();
}

class _BookingMealShareOptionsState
    extends ConsumerState<BookingMealShareOptions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = bookingMealOptionsProvider(widget.window);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.restaurant_menu_rounded),
      title: const Text('Chia sẻ thực đơn đã lưu'),
      onExpansionChanged: (value) => setState(() => _expanded = value),
      children: [
        if (_expanded)
          ref.watch(provider).when(
                skipLoadingOnReload: false,
                skipLoadingOnRefresh: false,
                loading: () => const LinearProgressIndicator(
                    semanticsLabel: 'Đang tải thực đơn đã lưu'),
                error: (_, __) => ListTile(
                  title: const Text('Chưa tải được thực đơn đã lưu.'),
                  trailing: IconButton(
                    tooltip: 'Tải lại thực đơn',
                    onPressed: () => ref.invalidate(provider),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                data: (plans) => _choices(context, plans),
              ),
      ],
    );
  }

  Widget _choices(BuildContext context, List<MealPlanSummaryModel> plans) {
    final options = plans.where((plan) {
      if (plan.status != 'saved') return false;
      if (widget.data.plans
          .any((shared) => shared.planId == plan.id && shared.canUse)) {
        return false;
      }
      return !widget.data.records.any((record) =>
          record.plannedDate == plan.plannedDate && record.planId != plan.id);
    }).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(plans.any((plan) => plan.status == 'stale')
                ? 'Có thực đơn cần kiểm tra lại trước khi chia sẻ.'
                : 'Chưa có thực đơn phù hợp để chia sẻ cho ngày của ca.'),
          ),
        for (final plan in options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Thực đơn ngày ${mealDateLabel(plan.plannedDate)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.disabled ? null : () => widget.onSelect(plan),
          ),
        TextButton(
          onPressed: widget.disabled
              ? null
              : () async {
                  await context.push(AppRoutes.beneficiaryNutrition(
                      widget.window.beneficiaryId));
                  if (mounted) {
                    ref.invalidate(bookingMealOptionsProvider(widget.window));
                  }
                },
          child: const Text('Mở thực đơn dinh dưỡng'),
        ),
      ],
    );
  }
}
