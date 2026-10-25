import 'nutrition_flow_model.dart';
import '../../../../core/utils/date_formatter.dart';

enum NutritionMenuOverviewTone { neutral, primary, success, warning, error }

/// Flattens workflow state into the small set of values needed by the menu UI.
class NutritionMenuOverviewModel {
  const NutritionMenuOverviewModel({
    required this.title,
    required this.description,
    required this.badgeLabel,
    required this.tone,
    required this.mealCount,
    required this.totalKcal,
    required this.plannedDate,
  });

  final String title;
  final String description;
  final String badgeLabel;
  final NutritionMenuOverviewTone tone;
  final int mealCount;
  final num totalKcal;
  final DateTime plannedDate;

  bool get hasMeals => mealCount > 0;

  factory NutritionMenuOverviewModel.fromFlow(
    NutritionFlow flow, {
    DateTime? selectedDate,
    bool hasPlanForSelectedDate = true,
    bool isLoadingSelectedDate = false,
  }) {
    final resource = flow.resource;
    final resourceDate = DateTime.tryParse(
      resource?.result.plannedDate ?? '',
    );
    final plannedDate = selectedDate ?? resourceDate ?? DateTime.now();
    final hasSelectedPlan = !isLoadingSelectedDate &&
        resource != null &&
        hasPlanForSelectedDate &&
        (selectedDate == null ||
            resourceDate == null ||
            _sameDate(resourceDate, plannedDate));
    final meals = hasSelectedPlan && resource.status != 'stale'
        ? resource.result.meals
        : const [];
    final totalKcal = meals.fold<num>(
      0,
      (sum, meal) => sum + (meal.energyKcal ?? 0),
    );
    final status = isLoadingSelectedDate
        ? 'loading_plan'
        : hasSelectedPlan
            ? resource.status
            : 'no_plan';
    final decisionState =
        hasSelectedPlan ? resource.result.decision.state : null;
    final state = status == 'saved'
        ? 'saved'
        : status == 'stale'
            ? 'stale'
            : decisionState?.isNotEmpty == true
                ? decisionState!
                : status;
    final copy = _copyFor(state, hasMeals: meals.isNotEmpty);

    return NutritionMenuOverviewModel(
      title: hasSelectedPlan
          ? meals.isEmpty
              ? 'Tổng quan dinh dưỡng'
              : 'Thực đơn ngày ${formatDate(plannedDate, includeYear: false)}'
          : 'Thực đơn ngày ${plannedDate.day}/${plannedDate.month}',
      description: copy.description,
      badgeLabel: copy.badgeLabel,
      tone: copy.tone,
      mealCount: meals.length,
      totalKcal: totalKcal,
      plannedDate: plannedDate,
    );
  }

  static _OverviewCopy _copyFor(String state, {required bool hasMeals}) =>
      switch (state) {
        'saved' => const _OverviewCopy(
            'Đã lưu theo hồ sơ dinh dưỡng',
            'Đã lưu',
            NutritionMenuOverviewTone.success,
          ),
        'suggested' => _OverviewCopy(
            hasMeals ? 'Gợi ý mới, chưa lưu' : 'Đang chuẩn bị gợi ý',
            hasMeals ? 'Bản gợi ý' : 'Đang tạo',
            NutritionMenuOverviewTone.primary,
          ),
        'queued' || 'processing' => const _OverviewCopy(
            'Đang phân tích thông tin dinh dưỡng',
            'Đang tạo',
            NutritionMenuOverviewTone.neutral,
          ),
        'needs_information' => const _OverviewCopy(
            'Cần bổ sung thông tin để tiếp tục',
            'Cần bổ sung',
            NutritionMenuOverviewTone.warning,
          ),
        'needs_professional_guidance' => const _OverviewCopy(
            'Cần hướng dẫn phù hợp trước khi gợi ý',
            'Cần hướng dẫn',
            NutritionMenuOverviewTone.warning,
          ),
        'awaiting_confirmation' => const _OverviewCopy(
            'Vui lòng kiểm tra lại bản tóm tắt',
            'Chờ xác nhận',
            NutritionMenuOverviewTone.warning,
          ),
        'eligible' => const _OverviewCopy(
            'Thông tin đã sẵn sàng để tạo gợi ý',
            'Sẵn sàng',
            NutritionMenuOverviewTone.primary,
          ),
        'no_content' => const _OverviewCopy(
            'Kho thực đơn hiện chưa có đủ dữ liệu',
            'Chưa có món',
            NutritionMenuOverviewTone.neutral,
          ),
        'no_plan' => const _OverviewCopy(
            'Chọn ngày để xem thực đơn đã lưu',
            'Chưa có thực đơn',
            NutritionMenuOverviewTone.neutral,
          ),
        'loading_plan' => const _OverviewCopy(
            'Đang tìm thực đơn cho ngày đã chọn',
            'Đang tải',
            NutritionMenuOverviewTone.neutral,
          ),
        'no_match' => const _OverviewCopy(
            'Chưa có thực đơn phù hợp với thông tin đã xác nhận',
            'Chưa phù hợp',
            NutritionMenuOverviewTone.warning,
          ),
        'failed' => const _OverviewCopy(
            'Chưa phân tích được thông tin dinh dưỡng',
            'Có lỗi',
            NutritionMenuOverviewTone.error,
          ),
        'stale' => const _OverviewCopy(
            'Thông tin đã thay đổi, cần kiểm tra lại',
            'Cần kiểm tra',
            NutritionMenuOverviewTone.warning,
          ),
        _ => const _OverviewCopy(
            'Đang chuẩn bị thông tin thực đơn',
            'Đang chuẩn bị',
            NutritionMenuOverviewTone.neutral,
          ),
      };

  static bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _OverviewCopy {
  const _OverviewCopy(this.description, this.badgeLabel, this.tone);

  final String description;
  final String badgeLabel;
  final NutritionMenuOverviewTone tone;
}
