import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../controllers/booking_controller.dart';
import '../models/booking_status_presentation.dart';
import 'booking_appointment_summary.dart';
import 'booking_payment_summary.dart';
import 'booking_financial_summary.dart';
import 'booking_detail_screen_progress_tracker.dart';
import 'booking_detail_screen_waiting_caregiver_card.dart';
import 'booking_detail_screen_caregiver_hero_card.dart';
import 'booking_detail_hero.dart';

class BookingDetailContent extends StatelessWidget {
  const BookingDetailContent(
      {super.key,
      required this.booking,
      required this.statusConfig,
      required this.onRefresh,
      required this.onChat,
      required this.actions});
  final BookingModel booking;
  final BookingStatusPresentation statusConfig;
  final Future<void> Function() onRefresh;
  final VoidCallback onChat;
  final Widget actions;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideStaggered(
                    index: 0,
                    child: BookingDetailHero(
                      booking: booking,
                      statusConfig: statusConfig,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideStaggered(
                    index: 1,
                    child: BookingDetailScreenProgressTracker(
                      statusConfig: statusConfig,
                      booking: booking,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideStaggered(
                    index: 2,
                    child: statusConfig.isWaitingCaregiver
                        ? const BookingDetailScreenWaitingCaregiverCard()
                        : BookingDetailScreenCaregiverHeroCard(
                            booking: booking,
                            onChat: onChat,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BookingAppointmentSummary(booking: booking),
                  const SizedBox(height: AppSpacing.compact),
                  BookingPaymentSummary(booking: booking),
                  if (booking.presentationStatusAt(DateTime.now()) ==
                      'completed')
                    BookingFinancialSummary(booking: booking),
                  const SizedBox(height: AppSpacing.lg),
                  actions,
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      );
}
