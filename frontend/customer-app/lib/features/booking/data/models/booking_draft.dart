/// Dữ liệu cần thiết để tạo một booking mới.
class BookingDraft {
  final String beneficiaryId;
  final String serviceTypeId;
  final String? caregiverId;
  final bool isSystemMatched;
  final String addressId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String? idempotencyKey;

  const BookingDraft({
    required this.beneficiaryId,
    required this.serviceTypeId,
    this.caregiverId,
    this.isSystemMatched = true,
    required this.addressId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.idempotencyKey,
  });
}
