import 'package:flutter/material.dart';
import '../../controllers/booking_wizard_state.dart';
import 'steps/service_step.dart';
import 'steps/recipient_step.dart';
import 'steps/time_step.dart';
import 'steps/caregiver_step.dart';
import 'steps/consent_step.dart';
import 'steps/confirm_step.dart';

class BookingWizardBody extends StatelessWidget {
  const BookingWizardBody({super.key, required this.args, required this.step});
  final BookingWizardArgs args;
  final int step;
  @override
  Widget build(BuildContext context) => switch (step) {
        0 => ServiceStep(args: args),
        1 => RecipientStep(args: args),
        2 => TimeStep(args: args),
        3 => CaregiverStep(args: args),
        4 => ConsentStep(args: args),
        5 => ConfirmStep(args: args),
        _ => const SizedBox.shrink(),
      };
}
