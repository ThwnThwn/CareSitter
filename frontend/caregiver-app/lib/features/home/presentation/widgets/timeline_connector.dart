import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class TimelineConnector extends StatelessWidget {
  const TimelineConnector(
      {super.key,
      required this.isFirst,
      required this.isActive,
      required this.isLast});
  final bool isFirst;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        child: Column(
          children: [
            // Top line
            if (!isFirst)
              Container(
                width: 2,
                height: 8,
                color: AppColors.border,
              ),
            // Node
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.border,
                shape: BoxShape.circle,
                border: isActive
                    ? null
                    : Border.all(color: AppColors.textHint, width: 1),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : AppColors.textHint,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Bottom line
            if (!isLast)
              Expanded(
                child: Container(width: 2, color: AppColors.border),
              ),
          ],
        ),
      );
}
