import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_steps.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_header.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingProgressContent extends StatelessWidget {
  const BookingProgressContent(
      {super.key,
      required this.shortId,
      required this.currentStep,
      required this.steps,
      required this.callbackAction1});
  final String shortId;
  final int currentStep;
  final List<Map<String, Object>> steps;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingProgressHeader(
              callbackAction1: callbackAction1, shortId: shortId),
          const SizedBox(height: AppSpacing.md),
          BookingProgressSteps(currentStep: currentStep, steps: steps),
        ],
      );
}
