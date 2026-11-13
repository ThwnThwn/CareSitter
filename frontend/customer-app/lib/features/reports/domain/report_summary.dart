class ReportSummary {
  const ReportSummary(
      {required this.bookingId,
      required this.serviceName,
      required this.start,
      required this.end,
      required this.status,
      required this.amount});
  final String bookingId, serviceName, status;
  final DateTime start, end;
  final int amount;
}
