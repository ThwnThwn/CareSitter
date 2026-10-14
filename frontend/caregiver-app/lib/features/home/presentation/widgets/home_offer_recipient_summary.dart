import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'home_offer_recipient_location.dart';
import 'home_offer_earning.dart';

class HomeOfferRecipientSummary extends StatelessWidget {
  const HomeOfferRecipientSummary({super.key, required this.booking});
  final ShiftModel booking;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final recipient = HomeOfferRecipientLocation(booking: booking);
          final earning = HomeOfferEarning(booking: booking);
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 18.2) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  recipient,
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerRight, child: earning),
                ]);
          }
          return Row(children: [Expanded(child: recipient), earning]);
        }),
      );
}
