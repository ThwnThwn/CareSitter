import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_allergy_tag_field.dart';
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
    this.showErrors = false,
    this.missingFields = const [],
    this.allergyStatusKey,
    this.allergyDetailKey,
    this.conditionStatusKey,
    this.conditionDetailKey,
    this.allergyFocusNode,
    this.conditionFocusNode,
  });
  final bool showErrors;
  final List<String> missingFields;
  final Key? allergyStatusKey;
  final Key? allergyDetailKey;
  final Key? conditionStatusKey;
  final Key? conditionDetailKey;
  final FocusNode? allergyFocusNode;
  final FocusNode? conditionFocusNode;

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
            statusKey: allergyStatusKey,
            detailKey: allergyDetailKey,
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
            showErrors: showErrors,
            useTagInput: true,
            statusError: _hasMissingField('foodAllergyStatus'),
            detailError: _hasMissingField('allergies'),
            detailErrorText: _hasMissingField('allergies')
                ? 'Vui lòng kiểm tra thực phẩm chưa được nhận diện'
                : null,
            detailFocusNode: allergyFocusNode,
          ),
          const SizedBox(height: AppSpacing.compact),
          _ReportedStatusField(
            statusKey: conditionStatusKey,
            detailKey: conditionDetailKey,
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
            showErrors: showErrors,
            statusError: _hasMissingField('conditionsStatus'),
            detailError: _hasMissingField('chronicConditions'),
            detailErrorText: _hasMissingField('chronicConditions')
                ? 'Vui lòng kiểm tra thông tin bệnh lý này'
                : null,
            detailFocusNode: conditionFocusNode,
          ),
        ],
      );

  bool _hasMissingField(String field) => missingFields.any(
        (item) => item == field || item.startsWith('$field/'),
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
    required this.showErrors,
    required this.statusError,
    required this.detailError,
    this.statusKey,
    this.detailKey,
    this.detailErrorText,
    this.detailFocusNode,
    this.useTagInput = false,
  });
  final bool showErrors;
  final bool useTagInput;
  final bool statusError;
  final bool detailError;
  final Key? statusKey;
  final Key? detailKey;
  final String? detailErrorText;
  final FocusNode? detailFocusNode;

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
            key: statusKey,
            label: label,
            value: value,
            enabled: enabled,
            options: options,
            onChanged: onStatusChanged,
            error: statusError ||
                (showErrors &&
                    (value == 'unknown' ||
                        (value == 'reported_none' &&
                            controller.text.trim().isNotEmpty))),
          ),
          if (value == 'reported_present' || controller.text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            if (useTagInput)
              NutritionAllergyTagField(
                key: detailKey,
                controller: controller,
                enabled: enabled,
                maxLength: detailMaxLength,
                onChanged: onDetailChanged,
                focusNode: detailFocusNode,
                errorText: detailError
                    ? detailErrorText ?? 'Vui lòng kiểm tra thông tin này'
                    : showErrors &&
                            value == 'reported_present' &&
                            controller.text.trim().isEmpty
                        ? 'Vui lòng nhập ít nhất một thực phẩm gây dị ứng'
                        : null,
              )
            else
              TextField(
                key: detailKey,
                controller: controller,
                focusNode: detailFocusNode,
                enabled: enabled,
                maxLength: detailMaxLength,
                onChanged: onDetailChanged,
                decoration: InputDecoration(
                  labelText: detailLabel,
                  helperText: detailHelper,
                  errorText: detailError
                      ? detailErrorText ?? 'Vui lòng kiểm tra thông tin này'
                      : showErrors &&
                              value == 'reported_present' &&
                              controller.text.trim().isEmpty
                          ? 'Vui lòng nhập thông tin này'
                          : null,
                ),
              ),
          ],
        ],
      );
}
