import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftExtensionForm extends StatelessWidget {
  const ShiftExtensionForm(
      {super.key,
      required this.selectedHours,
      required this.onDecrease,
      required this.onIncrease,
      required this.effectiveHourlyRate,
      required this.onContactSupport});
  final int selectedHours;
  final VoidCallback onDecrease, onIncrease;
  final double effectiveHourlyRate;
  final void Function() onContactSupport;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Gia hạn ca chăm sóc',
              style: TextStyle(
                  fontSize: AppFontSizes.s18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.section),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 32),
                onPressed: selectedHours > 1 ? onDecrease : null,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text('$selectedHours giờ',
                  style: const TextStyle(
                      fontSize: AppFontSizes.s28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(width: AppSpacing.lg),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 32),
                onPressed: selectedHours < 4 ? onIncrease : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.inset),
          Text(
              'Phí ước tính: ${formatVnd(selectedHours * effectiveHourlyRate)}'),
          const SizedBox(height: AppSpacing.section),
          const Text(
              'Thời gian và phí chỉ là ước tính. Liên hệ hỗ trợ để xác nhận gia hạn.',
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            onPressed: onContactSupport,
            child: const Text('Liên hệ hỗ trợ'),
          ),
        ],
      );
}
