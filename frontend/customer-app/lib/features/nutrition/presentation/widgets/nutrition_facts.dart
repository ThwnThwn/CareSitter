import '../../data/models/nutrition_decision_model.dart';
import '../../data/models/nutrition_result_model.dart';
import '../models/nutrition_question_copy.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionFacts extends StatelessWidget {
  const NutritionFacts(
      {super.key,
      required this.decision,
      required this.data,
      required this.state});
  final NutritionDecisionModel decision;
  final NutritionResultModel data;
  final String state;
  @override
  Widget build(BuildContext context) {
    const fields = {
      'foodAllergyStatus': 'Xác nhận tình trạng dị ứng thực phẩm',
      'conditionsStatus': 'Xác nhận thông tin bệnh lý hiện có',
      'chronicConditions': 'Bổ sung bệnh đã được thông báo',
      'allergies': 'Làm rõ thực phẩm gây dị ứng',
      'unresolvedHealthFacts':
          'Làm rõ triệu chứng hoặc thông tin chưa chắc chắn'
    };
    final widgets = <Widget>[];
    if (decision.questions.isNotEmpty) {
      widgets.add(Text('Điểm cần làm rõ',
          style: Theme.of(context).textTheme.titleMedium));
      widgets.add(const SizedBox(height: AppSpacing.sm));
      for (final question in decision.questions) {
        widgets.add(ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: AppSpacing.sm,
            leading: const Icon(Icons.help_outline, color: AppColors.primary),
            title: Text(NutritionQuestionCopy.title(question)),
            subtitle: Text(NutritionQuestionCopy.hint(question))));
      }
    } else {
      for (final field in decision.missingFields) {
        widgets
            .add(Text('• ${fields[field] ?? _fieldLabel(field.toString())}'));
      }
    }
    if (decision.conflicts.isNotEmpty) {
      widgets.add(const Text(
          'Các nguồn thông tin đang khác nhau. Vui lòng kiểm tra lại hồ sơ; hệ thống giữ các hạn chế đã báo cáo.'));
    }
    if (state == 'needs_professional_guidance') {
      widgets.add(const Text(
          'Hồ sơ cần thêm hướng dẫn chuyên biệt hoặc đang ngoài phạm vi nội dung được hỗ trợ. Không tự đổi sang ăn mềm hay đặt giới hạn dinh dưỡng.'));
    }
    if (data.facts.isNotEmpty && state != 'stale') {
      widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text('Thông tin gia đình cung cấp',
              style: Theme.of(context).textTheme.titleMedium)));
    }
    for (final fact in data.facts) {
      if (state != 'stale') {
        widgets.add(ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(fact.label),
            subtitle: Text(
                '${_subject(fact.subject)} · ${_assertion(fact.assertion)} · ${_temporality(fact.temporality)}\n'
                '${_fieldLabel(fact.sourceKey)}${fact.quote.isEmpty ? '' : ' · “${fact.quote}”'}')));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  String _fieldLabel(String field) {
    if (field.startsWith('allergies')) return 'Dị ứng thực phẩm';
    if (field.startsWith('chronicConditions')) return 'Thông tin bệnh lý';
    if (field.startsWith('medications')) return 'Thuốc và trạng thái đang dùng';
    return {
          'foodAllergyStatus': 'Xác nhận dị ứng thực phẩm',
          'conditionsStatus': 'Xác nhận thông tin bệnh lý',
          'healthHistory/nutrition/medicationsStatus':
              'Xác nhận việc dùng thuốc hiện tại',
          'generalNote': 'Lưu ý sức khỏe',
          'careInstructions': 'Hướng dẫn chăm sóc',
          'mobilityNote': 'Khả năng vận động',
          'medications': 'Thuốc đang dùng',
          'healthHistory/nutrition/feedingRoute': 'Cách ăn uống',
          'healthHistory/nutrition/swallowingStatus': 'Khả năng nuốt',
          'healthHistory/nutrition/fluidRestriction': 'Hướng dẫn hạn chế nước',
          'healthHistory/nutrition/electrolyteRestriction':
              'Hướng dẫn về điện giải',
          'healthHistory/nutrition/symptoms': 'Triệu chứng đã báo cáo',
          'healthHistory/nutrition/guidance': 'Hướng dẫn ăn uống',
        }[field] ??
        'Thông tin sức khỏe cần được làm rõ';
  }

  String _assertion(Object? value) =>
      {
        'present': 'Đã báo cáo',
        'absent': 'Báo cáo không có',
        'uncertain': 'Chưa chắc chắn'
      }[value] ??
      'Cần làm rõ';
  String _temporality(Object? value) =>
      {
        'current': 'Hiện tại',
        'past': 'Trước đây',
        'unknown': 'Chưa rõ thời điểm'
      }[value] ??
      'Chưa rõ thời điểm';
  String _subject(Object? value) =>
      {
        'beneficiary': 'Người được hỗ trợ',
        'other': 'Người khác',
        'unknown': 'Chưa rõ người được nhắc tới'
      }[value] ??
      'Chưa rõ người được nhắc tới';
}
