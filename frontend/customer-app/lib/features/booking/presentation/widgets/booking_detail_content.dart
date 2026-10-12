import 'package:caresitter_customer/features/booking/presentation/widgets/booking_status_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_financial_summary.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_payment_summary.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_app_bar.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_appointment_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingDetailContent extends StatelessWidget {
  const BookingDetailContent(
      {super.key,
      required this.statusConfig,
      required this.isCancelling,
      required this.cancelDialogOpen,
      required this.showMoreOptions,
      required this.ref,
      required this.booking,
      required this.buildProgressTracker,
      required this.isWaitingCaregiver,
      required this.buildWaitingCaregiverCard,
      required this.buildCaregiverHeroCard,
      required this.buildInfoCard,
      required this.buildDetailRow,
      required this.buildPaymentRow,
      required this.formatCurrency,
      required this.status,
      required this.buildStatusBanner,
      required this.buildCancelButton,
      required this.action1,
      required this.action2,
      required this.action3,
      required this.action4,
      required this.action5,
      required this.action6,
      required this.action7,
      required this.action8,
      required this.action9});
  final BookingStatusPresentation statusConfig;
  final bool isCancelling;
  final bool cancelDialogOpen;
  final void Function(BuildContext, WidgetRef, BookingModel) showMoreOptions;
  final WidgetRef ref;
  final BookingModel booking;
  final Widget Function(BuildContext, BookingStatusPresentation, BookingModel)
      buildProgressTracker;
  final bool isWaitingCaregiver;
  final Widget Function(BuildContext) buildWaitingCaregiverCard;
  final Widget Function(BuildContext, BookingModel) buildCaregiverHeroCard;
  final Widget Function({required Widget child, required String title})
      buildInfoCard;
  final Widget Function(IconData, String, String) buildDetailRow;
  final Widget Function(String, double) buildPaymentRow;
  final String Function(double) formatCurrency;
  final String status;
  final Widget Function(String) buildStatusBanner;
  final Widget Function(BuildContext, WidgetRef, BookingModel)
      buildCancelButton;
  final Future<void> Function() action1;
  final void Function() action2;
  final void Function() action3;
  final void Function() action4;
  final void Function() action5;
  final void Function() action6;
  final void Function() action7;
  final void Function() action8;
  final void Function() action9;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: BookingDetailAppBar(
            statusConfig: statusConfig,
            isCancelling: isCancelling,
            cancelDialogOpen: cancelDialogOpen,
            showMoreOptions: showMoreOptions,
            ref: ref,
            booking: booking),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: action1,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Progress Tracker Bento (matching Stitch)
                FadeSlideStaggered(
                  index: 0,
                  child: buildProgressTracker(context, statusConfig, booking),
                ),
                const SizedBox(height: AppSpacing.md),

                // Hero Caregiver Profile Card (matching Stitch)
                FadeSlideStaggered(
                  index: 1,
                  child: isWaitingCaregiver
                      ? buildWaitingCaregiverCard(context)
                      : buildCaregiverHeroCard(context, booking),
                ),
                const SizedBox(height: AppSpacing.md),

                // Booking details
                BookingAppointmentSummary(
                    buildInfoCard: buildInfoCard,
                    buildDetailRow: buildDetailRow,
                    booking: booking),
                const SizedBox(height: AppSpacing.compact),

                // Payment
                BookingPaymentSummary(
                    buildInfoCard: buildInfoCard,
                    buildPaymentRow: buildPaymentRow,
                    booking: booking,
                    formatCurrency: formatCurrency),
                if (status == 'completed')
                  BookingFinancialSummary(
                      buildInfoCard: buildInfoCard,
                      buildPaymentRow: buildPaymentRow,
                      booking: booking),
                const SizedBox(height: AppSpacing.lg),

                // Actions
                BookingStatusActions(
                    status: status,
                    buildStatusBanner: buildStatusBanner,
                    action2: action2,
                    formatCurrency: formatCurrency,
                    booking: booking,
                    buildCancelButton: buildCancelButton,
                    ref: ref,
                    isWaitingCaregiver: isWaitingCaregiver,
                    action3: action3,
                    action4: action4,
                    action5: action5,
                    action6: action6,
                    action7: action7,
                    action8: action8,
                    action9: action9),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      );
}
