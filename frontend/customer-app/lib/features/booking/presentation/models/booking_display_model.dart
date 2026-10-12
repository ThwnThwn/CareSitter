import '../../data/models/booking_model.dart';
import '../../domain/booking_status_rules.dart';
import '../../domain/booking_amount_rules.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';

extension BookingDisplayModel on BookingModel {
  bool get isActive => BookingStatusRules.isActive(status);
  bool get isCompleted => status == 'completed';
  bool get isCancelled => BookingStatusRules.isCancelled(status);
  bool get isPendingPayment => status == 'pending_payment';
  bool get isEnRoute => status == 'caregiver_en_route';
  bool get isInProgress => status == 'in_progress';
  bool get isCheckoutPending => status == 'checkout_pending_review';
  bool get isCrisis => status == 'crisis';

  String presentationStatusAt(DateTime now) =>
      BookingStatusRules.presentationStatusAt(
          status: status,
          cancelledAt: cancelledAt,
          actualStart: actualStart,
          caregiverAssigned: caregiverId != null,
          now: now);
  bool isLiveTrackingAt(DateTime now) =>
      BookingStatusRules.isLiveStatus(presentationStatusAt(now));

  String get date => displayDate;
  String get time => displayTime;
  String get duration => displayDuration;
  String get address => addressText ?? 'Địa chỉ ca trực';
  double get totalPrice => escrowAmount.toDouble();
  String? get disputeReason => cancelReason;
  bool get isSystemMatched => true;
  String get paymentLabel => 'Thanh toán CareSitter';
  int get payableAmount =>
      BookingAmountRules.payable(escrowAmount, customerPayableAmount);
  double get platformRevenue => platformFeeAmount.toDouble();
  double get caregiverEarning =>
      BookingAmountRules.caregiverEarning(escrowAmount, platformFeeAmount)
          .toDouble();
  DateTime? get consentAcceptedAt => createdAt;
  DateTime? get checkoutRequestedAt => checkoutPendingReviewAt;
  DateTime? get completedAt => isCompleted ? updatedAt : null;

  String get displayDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date =
        DateTime(scheduledStart.year, scheduledStart.month, scheduledStart.day);
    if (date == today) {
      return 'Hôm nay, ${scheduledStart.day}/${scheduledStart.month}';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (date == tomorrow) {
      return 'Ngày mai, ${scheduledStart.day}/${scheduledStart.month}';
    }
    return formatDate(scheduledStart);
  }

  String get displayTime =>
      '${formatClock(scheduledStart)} – ${formatClock(scheduledEnd)}';

  String get displayDuration {
    final hours = scheduledEnd.difference(scheduledStart).inHours;
    return '$hours giờ';
  }

  String get caregiverInitials {
    if (caregiverName == null || caregiverName!.isEmpty) return '?';
    final parts =
        caregiverName!.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
