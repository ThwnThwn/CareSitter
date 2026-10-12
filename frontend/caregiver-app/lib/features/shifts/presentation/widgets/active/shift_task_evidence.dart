import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ShiftTaskEvidence extends StatelessWidget {
  const ShiftTaskEvidence({super.key, required this.urls});
  final List<String> urls;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        for (final url in urls)
          ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(url,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      width: 80,
                      height: 80,
                      child: Icon(Icons.broken_image_outlined))))
      ]);
}
