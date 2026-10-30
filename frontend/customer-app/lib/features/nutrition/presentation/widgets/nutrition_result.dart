import 'nutrition_facts.dart';
import 'nutrition_meal_card.dart';
import 'nutrition_recommendation_context.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../controllers/nutrition_controller.dart';
import '../models/nutrition_meal_presentation.dart';
import '../../domain/nutrition_error_copy.dart';

class NutritionResult extends StatelessWidget {
  const NutritionResult(
      {super.key,
      required this.flow,
      required this.controller,
      required this.plannedDate,
      required this.onReplace,
      this.menuOnly = false});
  final NutritionFlow flow;
  final NutritionFlowController controller;
  final DateTime plannedDate;
  final ValueChanged<String> onReplace;
  final bool menuOnly;
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _result(context, flow, controller));
  List<Widget> _result(
      BuildContext context, NutritionFlow flow, NutritionFlowController c) {
    final r = flow.resource!;
    final data = r.result;
    final decision = data.decision;
    final status = r.status;
    final state = status == 'stale' ? 'stale' : decision.state ?? status;
    final title = <String, String>{
          'queued': 'Đang chờ phân tích',
          'processing': 'Đang phân tích thông tin',
          'needs_information': 'Cần bổ sung thông tin',
          'needs_professional_guidance':
              'Cần hướng dẫn phù hợp trước khi gợi ý',
          'awaiting_confirmation': 'Kiểm tra bản tóm tắt',
          'eligible': 'Thông tin đã được xác nhận',
          'no_content': 'Chưa có dữ liệu thực đơn để gợi ý',
          'no_match': 'Chưa có thực đơn phù hợp',
          'failed': 'Chưa phân tích được thông tin',
          'stale': 'Thông tin đã thay đổi — cần kiểm tra lại',
          'suggested':
              status == 'saved' ? 'Thực đơn đã lưu' : 'Thực đơn được gợi ý'
        }[state] ??
        'Trạng thái: $status';
    final widgets = <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.compact)
    ];
    if (!menuOnly) {
      widgets.add(NutritionFacts(decision: decision, data: data, state: state));
    }
    if (state == 'no_content') {
      widgets.add(const Text(
          'Kho thực đơn hiện chưa có món đủ dữ liệu để gợi ý. Thông tin sức khỏe của bạn đã được giữ lại; vui lòng kiểm tra lại sau.'));
    }
    if (state == 'no_match') {
      widgets.add(const Text(
          'Chưa tìm được món đáp ứng các yêu cầu sức khỏe đã xác nhận. Thông tin của bạn đã được giữ lại; vui lòng kiểm tra lại sau.'));
    }
    if (state == 'failed') {
      widgets.add(Text(NutritionErrorCopy.failedAssessment(data.errorCode)));
    }
    widgets.add(const SizedBox(height: AppSpacing.compact));
    if (state == 'awaiting_confirmation' && decision.allows('confirm')) {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.confirm,
          child: const Text('Thông tin đúng, tiếp tục')));
    }
    if (state == 'eligible' &&
        flow.recommendationsEnabled &&
        decision.allows('recommend')) {
      widgets.add(FilledButton(
          onPressed:
              flow.loading ? null : () => c.recommend(plannedDate: plannedDate),
          child: const Text('Xem gợi ý thực đơn')));
    }
    if (state == 'stale') {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.reassess,
          child: const Text('Kiểm tra lại hồ sơ')));
    }
    if (state == 'failed' && data.retryable && decision.allows('retry')) {
      widgets.add(OutlinedButton(
          onPressed: flow.loading ? null : () => c.assess(retryFailed: true),
          child: const Text('Thử phân tích lại')));
    }
    if (state != 'stale') {
      final meals = data.meals;
      final trace = data.recommendationTrace;
      if (meals.isNotEmpty && trace != null) {
        widgets.add(NutritionRecommendationContext(
          trace: trace,
          meals: meals,
        ));
      }
      for (int i = 0; i < meals.length; i++) {
        final meal = meals[i];
        // Divider nhẹ giữa các section bữa ăn (trừ section đầu tiên)
        if (i > 0) {
          widgets.add(const Divider(
            height: AppSpacing.compact,
            indent: AppSpacing.section,
            endIndent: AppSpacing.section,
          ));
        }
        widgets.add(_MealSectionHeader(mealType: meal.mealType));
        widgets.add(NutritionMealCard(
            meal: meal,
            loading: flow.loading,
            canReplace: state == 'suggested' &&
                status != 'saved' &&
                decision.allows('replace'),
            onReplace: () => onReplace(meal.mealType)));
      }
    }
    if (state == 'suggested' && status != 'saved' && decision.allows('save')) {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.save,
          child: const Text('Lưu thực đơn')));
    }
    return widgets;
  }
}

// ── Section header: icon + label bữa ăn ─────────────────────────────────────

class _MealSectionHeader extends StatelessWidget {
  const _MealSectionHeader({required this.mealType});

  final String mealType;

  @override
  Widget build(BuildContext context) {
    final meta = NutritionMealPresentation.forType(mealType);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        AppSpacing.compact,
        0,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: meta.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.compact),
            ),
            child: Icon(meta.icon, size: 16, color: meta.iconColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            meta.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
