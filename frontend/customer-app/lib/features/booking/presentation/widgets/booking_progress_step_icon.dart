import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookingProgressStepIcon extends StatelessWidget {
  const BookingProgressStepIcon(
      {super.key,
      required this.circleBg,
      required this.border,
      required this.isActive,
      required this.isPassed,
      required this.steps,
      required this.idx,
      required this.iconColor});
  final Color circleBg;
  final Border? border;
  final bool isActive;
  final bool isPassed;
  final List<Map<String, Object>> steps;
  final int idx;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: circleBg,
          shape: BoxShape.circle,
          border: border,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            isPassed ? Icons.check : (steps[idx]['icon'] as IconData),
            size: 14,
            color: iconColor,
          ),
        ),
      );
}
