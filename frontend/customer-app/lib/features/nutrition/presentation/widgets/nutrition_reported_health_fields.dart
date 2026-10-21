import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_status_field.dart';

class NutritionReportedHealthFields extends StatelessWidget {
  const NutritionReportedHealthFields({
    super.key,
    required this.enabled,
    required this.allergyStatus,
    required this.conditionStatus,
    required this.allergyController,
    required this.conditionController,
    required this.onAllergyStatusChanged,
    required this.onConditionStatusChanged,
    required this.onAllergiesChanged,
    required this.onConditionsChanged,
  });

  final bool enabled;
  final String allergyStatus;
  final String conditionStatus;
  final TextEditingController allergyController;
  final TextEditingController conditionController;
  final ValueChanged<String> onAllergyStatusChanged;
  final ValueChanged<String> onConditionStatusChanged;
  final ValueChanged<String> onAllergiesChanged;
  final ValueChanged<String> onConditionsChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _ReportedStatusField(
            label: 'Dị ứng thực phẩm',
            value: allergyStatus,
            enabled: enabled,
            options: const {
              'unknown': 'Chưa rõ',
              'reported_present': 'Có dị ứng thực phẩm',
              'reported_none': 'Đã xác nhận không có',
            },
            controller: allergyController,
            detailLabel: 'Thực phẩm gây dị ứng *',
            detailHelper: 'Bắt buộc khi có dị ứng. Ngăn cách bằng dấu ;',
            detailMaxLength: 1000,
            onStatusChanged: onAllergyStatusChanged,
            onDetailChanged: onAllergiesChanged,
          ),
          const SizedBox(height: AppSpacing.compact),
          _ReportedStatusField(
            label: 'Thông tin bệnh lý hiện có',
            value: conditionStatus,
            enabled: enabled,
            options: const {
              'unknown': 'Chưa rõ / cần cập nhật',
              'reported_present': 'Có thông tin bệnh lý',
              'reported_none': 'Gia đình xác nhận chưa có bệnh lý',
            },
            controller: conditionController,
            detailLabel: 'Bệnh lý đã biết *',
            detailHelper:
                'Bắt buộc khi có bệnh. Chỉ nhập thông tin đã được ghi nhận; ngăn cách bằng dấu ;.',
            detailMaxLength: 2000,
            onStatusChanged: onConditionStatusChanged,
            onDetailChanged: onConditionsChanged,
          ),
        ],
      );
}

class _ReportedStatusField extends StatelessWidget {
  const _ReportedStatusField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.options,
    required this.controller,
    required this.detailLabel,
    required this.detailHelper,
    required this.detailMaxLength,
    required this.onStatusChanged,
    required this.onDetailChanged,
  });

  final String label;
  final String value;
  final bool enabled;
  final Map<String, String> options;
  final TextEditingController controller;
  final String detailLabel;
  final String detailHelper;
  final int detailMaxLength;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDetailChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          NutritionStatusField(
            label: label,
            value: value,
            enabled: enabled,
            options: options,
            onChanged: onStatusChanged,
          ),
          if (value == 'reported_present' || controller.text.isNotEmpty)
            TextField(
              controller: controller,
              enabled: enabled,
              maxLength: detailMaxLength,
              onChanged: onDetailChanged,
              decoration: InputDecoration(
                labelText: detailLabel,
                helperText: detailHelper,
              ),
            ),
        ],
      );
}
