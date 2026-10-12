import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_step_icon.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_step_label.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_bar.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_track.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingProgressSteps extends StatelessWidget {
  const BookingProgressSteps(
      {super.key, required this.currentStep, required this.steps});
  final int currentStep;
  final List<Map<String, Object>> steps;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 36;
          final progressWidth = trackWidth * (currentStep.clamp(0, 3) / 3.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Background track line
              const BookingProgressTrack(),
              // Active progress track line
              BookingProgressBar(progressWidth: progressWidth),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(steps.length, (idx) {
                  final isPassed = idx < currentStep;
                  final isActive = idx == currentStep;

                  Color circleBg;
                  Color iconColor;
                  Border? border;

                  if (isPassed) {
                    circleBg = AppColors.primary;
                    iconColor = Colors.white;
                  } else if (isActive) {
                    circleBg = AppColors.primary;
                    iconColor = Colors.white;
                    border = Border.all(
                      color: AppColors.primaryContainer,
                      width: 3,
                    );
                  } else {
                    circleBg = AppColors.border;
                    iconColor = AppColors.textSecondary;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BookingProgressStepIcon(
                          circleBg: circleBg,
                          border: border,
                          isActive: isActive,
                          isPassed: isPassed,
                          steps: steps,
                          idx: idx,
                          iconColor: iconColor),
                      const SizedBox(height: AppSpacing.tight),
                      BookingProgressStepLabel(
                          steps: steps,
                          idx: idx,
                          isActive: isActive,
                          isPassed: isPassed),
                    ],
                  );
                }),
              ),
            ],
          );
        },
      );
}
