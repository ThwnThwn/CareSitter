import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftMapAddress extends StatelessWidget {
  const ShiftMapAddress({super.key, required this.address});
  final String address;

  @override
  Widget build(BuildContext context) => Text(
        address,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: AppFontSizes.s13,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      );
}
