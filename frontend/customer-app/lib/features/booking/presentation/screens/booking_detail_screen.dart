import '../widgets/booking_detail_app_bar.dart';
import '../widgets/booking_status_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_complete_shift_dialog_content_inner.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_complete_shift_dialog_row.dart';
import '../widgets/booking_extension_unavailable_dialog.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_missing_state.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_more_options_ctx_status_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_complete_shift_dialog_booking_fields.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_screen_cancel_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/payment_checkout_sheet.dart';
import '../../data/models/payment_intent_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/core/widgets/confirm_action_dialog.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const BookingDetailScreen({super.key, required this.id});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isCancelling = false;
  bool _cancelDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(bookingStoreProvider).where((b) => b.id == widget.id);
    if (matches.isEmpty) {
      return const BookingDetailMissingState();
    }
    final booking = matches.first;
    final now = DateTime.now();
    final status = booking.presentationStatusAt(now);
    final statusConfig = BookingStatusPresentation.forBooking(booking, now: now);
    final isWaitingCaregiver = statusConfig.isWaitingCaregiver;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BookingDetailAppBar(
          statusConfig: statusConfig,
          onMoreOptions: _isCancelling || _cancelDialogOpen
              ? null
              : () => _showMoreOptions(context, ref, booking)),
      body: BookingDetailContent(
        booking: booking,
        statusConfig: statusConfig,
        onRefresh: () => ref.read(bookingStoreProvider.notifier).refresh(),
        actions: BookingStatusActions(
          booking: booking,
          status: status,
          isWaitingCaregiver: isWaitingCaregiver,
          cancelButton: BookingDetailScreenCancelButton(
              booking: booking,
              isCancelling: _isCancelling,
              cancelDialogOpen: _cancelDialogOpen,
              confirmCancel: _confirmCancel),
          onPay: () => _handleConfirmPayment(context, ref, booking),
          onTrack: () => context.push('/bookings/${booking.id}/tracking'),
          onExtend: () => showDialog<void>(
            context: context,
            builder: (_) => const BookingExtensionUnavailableDialog(),
          ),
          onComplete: () => _showCompleteShiftDialog(context, ref, booking),
          onDispute: () => context.push('/bookings/${booking.id}/dispute'),
          onReview: () => context.push('/bookings/${booking.id}/review'),
          onRebook: () => context.push('/booking/new'),
          onChat: () => context.push('/bookings/${booking.id}/chat'),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BookingModel booking) async {
    if (_isCancelling || _cancelDialogOpen) return;
    setState(() => _cancelDialogOpen = true);
    try {
      final confirmed = await showConfirmActionDialog(
        context,
        title: 'Hủy lịch hẹn?',
        message: 'Lịch hẹn ngày ${booking.date}, ${booking.time} sẽ bị hủy.\n'
            'Khoản thanh toán (nếu có) vẫn cần được đối soát.',
        confirmLabel: 'Hủy lịch hẹn',
      );
      if (!confirmed || !mounted) return;
      setState(() {
        _cancelDialogOpen = false;
        _isCancelling = true;
      });

      await ref.read(bookingStoreProvider.notifier).cancel(booking.id);
      if (!mounted) return;
      AppToast.success(context, 'Đã hủy lịch hẹn');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        error is AppApiException
            ? error.message
            : 'Không thể hủy lịch hẹn. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelDialogOpen = false;
          _isCancelling = false;
        });
      }
    }
  }

  void _showCompleteShiftDialog(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const BookingDetailShowCompleteShiftDialogRow(),
        content: BookingDetailShowCompleteShiftDialogBookingFields(booking: booking),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child:
                const Text('Chưa', style: TextStyle(color: AppColors.textSecondary)),
          ),
          BookingDetailShowCompleteShiftDialogContentInner(
              callbackAction1: () async {
            Navigator.pop(dCtx);
            AppToast.loading(context, 'Đang xác nhận hoàn tất ca…');
            try {
              await ref
                  .read(bookingStoreProvider.notifier)
                  .confirmCompleted(booking.id);
              if (!context.mounted) return;
              AppToast.success(context, 'Ca chăm sóc đã được xác nhận hoàn tất.');
            } catch (_) {
              if (!context.mounted) return;
              AppToast.error(
                  context, 'Không thể xác nhận lúc này. Vui lòng thử lại.');
            }
          }),
        ],
      ),
    );
  }

  Future<void> _handleConfirmPayment(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) async {
    final intent = await showModalBottomSheet<PaymentIntentModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) => PaymentCheckoutSheet(booking: booking),
    );
    if (intent == null || !context.mounted) return;
    context.go(Uri(path: '/payment-result', queryParameters: {
      'bookingId': booking.id,
      if (intent.id.isNotEmpty) 'intentId': intent.id,
      'result': 'pending',
    }).toString());
  }

  void _showMoreOptions(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) {
    final status = booking.presentationStatusAt(DateTime.now());
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BookingDetailShowMoreOptionsCtxStatusContent(
          ctx: ctx, status: status, confirmCancel: _confirmCancel, booking: booking),
    );
  }
}

