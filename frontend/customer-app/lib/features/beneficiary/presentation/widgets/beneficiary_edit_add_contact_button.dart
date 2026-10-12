import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryEditAddContactButton extends StatelessWidget {
  const BeneficiaryEditAddContactButton({super.key, required this.action7});
  final void Function() action7;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: action7,
        icon: const Icon(Icons.add_circle_outline, size: 18),
        label: const Text('Thêm liên hệ khẩn cấp'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.control),
        ),
      );
}
