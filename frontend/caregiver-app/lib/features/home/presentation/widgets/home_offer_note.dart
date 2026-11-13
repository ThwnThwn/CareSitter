import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeOfferNote extends StatelessWidget {
  const HomeOfferNote({super.key, required this.note});
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Text(
          note == null || note!.isEmpty ? 'Chưa có ghi chú' : '"$note"',
          style: const TextStyle(fontFamily: 'Inter',
            fontSize: AppFontSizes.s12,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
        ),
      );
}
