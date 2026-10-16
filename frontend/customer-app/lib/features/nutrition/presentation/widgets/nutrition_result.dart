import 'nutrition_facts.dart';
import 'nutrition_meal_card.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../controllers/nutrition_controller.dart';
import '../../domain/nutrition_error_codes.dart';

class NutritionResult extends StatelessWidget {
  const NutritionResult(
      {super.key,
      required this.flow,
      required this.controller,
      required this.onReplace});
  final NutritionFlow flow;
  final NutritionFlowController controller;
  final ValueChanged<String> onReplace;
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
          'no_content': 'Chưa có công thức đã duyệt cho nhu cầu này',
          'no_match': 'Chưa tìm được món đáp ứng các yêu cầu',
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
    widgets.add(NutritionFacts(decision: decision, data: data, state: state));
    if (state == 'failed') {
      widgets.add(Text(data.errorCode == NutritionErrorCodes.aiUnavailable
          ? 'Dịch vụ AI chưa được cấu hình. Thông tin đã nhập vẫn được giữ.'
          : 'Phân tích chưa thành công. Thông tin đã nhập vẫn được giữ.'));
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
          onPressed: flow.loading ? null : c.recommend,
          child: const Text('Xem gợi ý thực đơn')));
    }
    if (state == 'stale') {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.load,
          child: const Text('Kiểm tra lại hồ sơ')));
    }
    if (state == 'failed' && data.retryable && decision.allows('retry')) {
      widgets.add(OutlinedButton(
          onPressed: flow.loading ? null : () => c.assess(retryFailed: true),
          child: const Text('Thử phân tích lại')));
    }
    for (final meal in data.meals) {
      if (state != 'stale') {
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
