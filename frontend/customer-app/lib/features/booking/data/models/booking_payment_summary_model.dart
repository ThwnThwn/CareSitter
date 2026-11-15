class BookingPaymentSummaryModel {
  const BookingPaymentSummaryModel(
      {required this.bookingId,
      required this.amountDue,
      required this.canPay,
      required this.canCancel,
      required this.refundIfCancelledNow,
      required this.paymentExplanation,
      required this.settlementExplanation,
      required this.matchingExplanation,
      required this.cancellationExplanation,
      this.refundAfterPaymentIfCancelledNow,
      this.afterPaymentCancellationExplanation});
  final String bookingId;
  final int amountDue;
  final bool canPay, canCancel;
  final int? refundIfCancelledNow;
  final int? refundAfterPaymentIfCancelledNow;
  final String? afterPaymentCancellationExplanation;
  final String paymentExplanation,
      settlementExplanation,
      matchingExplanation,
      cancellationExplanation;

  factory BookingPaymentSummaryModel.fromJson(Map<String, dynamic> json) =>
      BookingPaymentSummaryModel(
        bookingId: json['bookingId'] as String,
        amountDue: (json['amountDue'] as num).toInt(),
        canPay: json['canPay'] == true,
        canCancel: json['canCancel'] == true,
        refundIfCancelledNow: (json['refundIfCancelledNow'] as num?)?.toInt(),
        paymentExplanation: json['paymentExplanation'] as String,
        settlementExplanation: json['settlementExplanation'] as String,
        matchingExplanation: json['matchingExplanation'] as String,
        cancellationExplanation: json['cancellationExplanation'] as String,
        refundAfterPaymentIfCancelledNow:
            (json['refundAfterPaymentIfCancelledNow'] as num?)?.toInt(),
        afterPaymentCancellationExplanation:
            json['afterPaymentCancellationExplanation'] as String?,
      );

  String get explanation => [
        paymentExplanation,
        settlementExplanation,
        matchingExplanation,
        cancellationExplanation
      ].join('\n\n');
}
