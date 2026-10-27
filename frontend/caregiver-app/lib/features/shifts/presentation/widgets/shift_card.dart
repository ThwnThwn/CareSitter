import 'package:caregiver_app/features/shifts/presentation/widgets/shift_card_recipient_service.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_card_checkout_notice.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_card_offer_actions.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_card_schedule_metadata.dart';
import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftCard extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback onTap;
  final Future<void> Function()? onDecline;
  final VoidCallback? onViewOffer;

  const ShiftCard({
    super.key,
    required this.shift,
    required this.onTap,
    this.onDecline,
    this.onViewOffer,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = shift.statusType == ShiftStatus.pending ||
        shift.statusType == ShiftStatus.open;
    final isCheckoutPending =
        shift.statusType == ShiftStatus.checkoutPendingReview;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isPending
              ? AppColors.statusPending.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShiftCardRecipientService(shift: shift),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                ShiftCardScheduleMetadata(shift: shift),
                if (isCheckoutPending) ...[
                  const SizedBox(height: AppSpacing.inset),
                  const ShiftCardCheckoutNotice(),
                ],
                if (onDecline != null && onViewOffer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ShiftCardOfferActions(
                      onViewOffer: onViewOffer,
                      onDecline: () async {
                        try {
                          await onDecline!();
                        } catch (error) {
                          if (context.mounted) {
                            AppToast.error(
                              context,
                              error.toString(),
                              title: 'Chưa từ chối được ca',
                            );
                          }
                        }
                      }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
