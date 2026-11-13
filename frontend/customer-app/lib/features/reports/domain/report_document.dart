import 'dart:typed_data';

class ReportDocument {
  const ReportDocument(
      {required this.bytes,
      required this.idempotencyKey,
      this.attempted = false,
      this.completedId});
  final Uint8List bytes;
  final String idempotencyKey;
  final bool attempted;
  final String? completedId;
  ReportDocument withOutcome({bool attempted = true, String? completedId}) =>
      ReportDocument(
          bytes: bytes,
          idempotencyKey: idempotencyKey,
          attempted: attempted,
          completedId: completedId);
}
