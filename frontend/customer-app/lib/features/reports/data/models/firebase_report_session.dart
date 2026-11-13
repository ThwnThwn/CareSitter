import 'report_receipt.dart';

class FirebaseReportSession {
  const FirebaseReportSession(
      {required this.report,
      required this.uid,
      required this.projectId,
      required this.bucket,
      required this.objectPath,
      required this.customToken,
      required this.expiresAtMs});
  final ReportReceipt report;
  final String uid, projectId, bucket, objectPath;
  final String? customToken;
  final int expiresAtMs;

  factory FirebaseReportSession.fromJson(Map<String, dynamic> json) =>
      FirebaseReportSession(
          report:
              ReportReceipt.fromJson(json['report'] as Map<String, dynamic>),
          uid: json['uid'] as String,
          projectId: json['projectId'] as String,
          bucket: json['bucket'] as String,
          objectPath: json['objectPath'] as String,
          customToken: json['customToken'] as String?,
          expiresAtMs: (json['expiresAtMs'] as num).toInt());

  bool belongsTo(String owner, String booking) =>
      uid == owner.toLowerCase() &&
      report.bookingId == booking &&
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(report.id) &&
      objectPath ==
          'reports/$uid/${report.id.replaceAll('-', '').toLowerCase()}.pdf' &&
      bucket.isNotEmpty &&
      !bucket.contains('/') &&
      projectId.isNotEmpty;
}
