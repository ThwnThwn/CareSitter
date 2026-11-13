import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../domain/report_document.dart';
import '../../domain/report_request.dart';
import '../models/report_receipt.dart';
import '../models/firebase_report_session.dart';
import '../services/firebase_report_storage_service.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) =>
    ReportsRepository(ref.watch(dioClientProvider),
        owner:
            ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId))));

class ReportsRepository {
  ReportsRepository(this._client,
      {String? owner,
      FirebaseReportStorageService? storage,
      bool firebaseStorageEnabled = false})
      : _owner = owner,
        _firebaseStorageEnabled = firebaseStorageEnabled,
        _storage = storage ?? FirebaseReportStorageService();
  final DioClient _client;
  final String? _owner;
  final FirebaseReportStorageService _storage;
  final bool _firebaseStorageEnabled;
  Future<List<ReportReceipt>> list(String booking,
      {int page = 1, int pageSize = 20}) async {
    final response = await _client.get<List<dynamic>>(
        '/bookings/$booking/reports',
        query: {'page': page, 'pageSize': pageSize});
    return (response.data ?? [])
        .map((item) => ReportReceipt.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  ReportRequest<ReportReceipt> upload(String booking, ReportDocument document,
      void Function(int sent, int total) progress) {
    if (_firebaseStorageEnabled) {
      return _uploadFirebase(booking, document, progress);
    }
    final cancellation = CancelToken();
    final result = _client
        .postForm<Map<String, dynamic>>(
          '/bookings/$booking/reports',
          FormData.fromMap({
            'file': MultipartFile.fromBytes(document.bytes,
                filename: 'caresitter-report.pdf',
                contentType: DioMediaType('application', 'pdf'))
          }),
          idempotencyKey: document.idempotencyKey,
          cancelToken: cancellation,
          onSendProgress: progress,
        )
        .then((response) => ReportReceipt.fromJson(response.data!));
    return ReportRequest(result, () => cancellation.cancel());
  }

  ReportRequest<ReportReceipt> _uploadFirebase(String booking,
      ReportDocument document, void Function(int sent, int total) progress) {
    final cancellation = CancelToken();
    ReportRequest<void>? sending;
    void check() {
      if (cancellation.isCancelled) {
        throw const AppApiException(
            message: 'Đã dừng gửi báo cáo.', isCancelled: true);
      }
    }

    Future<ReportReceipt> run() async {
      final owner = _owner;
      if (owner == null) {
        throw const AppApiException(message: 'Cần đăng nhập.', statusCode: 401);
      }
      final checksum = sha256.convert(document.bytes).toString();
      final response = await _client.postCancelable<Map<String, dynamic>>(
          '/bookings/$booking/reports/firebase-session',
          cancelToken: cancellation,
          data: {
            'idempotencyKey': document.idempotencyKey,
            'sizeBytes': document.bytes.length,
            'checksum': checksum
          });
      check();
      final session = FirebaseReportSession.fromJson(response.data!);
      if (!session.belongsTo(owner, booking) ||
          session.report.sizeBytes != document.bytes.length) {
        throw const AppApiException(
            message: 'Phiên lưu báo cáo không khớp tài khoản hoặc tệp.',
            statusCode: 403,
            code: 'report.session_owner');
      }
      if (session.report.completed) return session.report;
      sending = _storage.upload(session, document.bytes, checksum, progress);
      await sending!.result;
      check();
      final completed = await _client.postCancelable<Map<String, dynamic>>(
          '/reports/${session.report.id}/firebase-completion',
          cancelToken: cancellation);
      check();
      final receipt = ReportReceipt.fromJson(completed.data!);
      if (receipt.id != session.report.id ||
          receipt.bookingId != booking ||
          receipt.sizeBytes != document.bytes.length ||
          !receipt.completed) {
        throw const AppApiException(
            message: 'Máy chủ chưa xác nhận lưu báo cáo.',
            statusCode: 503,
            code: 'report.upload_pending');
      }
      return receipt;
    }

    return ReportRequest(run(), () {
      cancellation.cancel();
      sending?.cancel();
    });
  }

  Future<Uint8List> download(String id) =>
      _client.getBytes('/reports/$id/content');
}
