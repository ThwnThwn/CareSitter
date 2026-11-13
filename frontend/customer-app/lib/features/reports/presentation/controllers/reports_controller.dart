import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import '../../domain/report_document.dart';
import '../../domain/report_request.dart';
import '../../domain/report_summary.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/services/pdf_report_documents.dart';
import '../../data/services/report_draft_store.dart';
import 'report_state.dart';
export 'report_state.dart';

final reportsControllerProvider =
    AutoDisposeNotifierProvider.family<ReportsController, ReportState, String>(
        ReportsController.new);

class ReportsController extends AutoDisposeFamilyNotifier<ReportState, String> {
  ReportDocument? _document;
  ReportRequest<dynamic>? _upload;
  int _revision = 0;
  String? _owner;
  int _session = 0;

  @override
  ReportState build(String arg) {
    final auth = ref.watch(authStateProvider.select(
        (s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
    _owner = auth.$2 == true ? auth.$1 : null;
    _session = ref.read(authStateProvider.notifier).sessionGeneration;
    _document = null;
    final revision = ++_revision;
    ref.onDispose(() {
      _revision++;
      _upload?.cancel();
    });
    Future.microtask(() => _restore(revision));
    return const ReportState();
  }

  bool _current(int revision) =>
      revision == _revision &&
      _owner != null &&
      ref.read(authStateProvider.notifier).sessionGeneration == _session;

  Future<void> _restore(int revision) async {
    if (!_current(revision)) return;
    try {
      final document =
          await ref.read(reportDraftStoreProvider).load(_owner!, arg);
      if (_current(revision)) {
        _document = document;
        state = ReportState(
            phase: ReportPhase.idle,
            hasDocument: _document != null,
            reportId: _document?.completedId,
            uncertain:
                _document?.attempted == true && _document?.completedId == null);
      }
    } catch (_) {
      if (_current(revision)) {
        state = const ReportState(
            phase: ReportPhase.idle,
            error: 'Chưa đọc được bản PDF đã lưu. Vui lòng mở lại màn hình.');
      }
    }
  }

  Future<void> generate() async {
    if (state.busy || _owner == null || state.uncertain) return;
    final revision = _revision;
    state = state.copyWith(phase: ReportPhase.generating);
    try {
      final booking = await ref.read(bookingRepositoryProvider).getBooking(arg);
      if (!_current(revision)) return;
      final bytes = await ref.read(reportDocumentsProvider).generate(
          ReportSummary(
              bookingId: booking.id,
              serviceName: booking.serviceName ?? 'Dịch vụ chăm sóc',
              start: booking.scheduledStart,
              end: booking.scheduledEnd,
              status: booking.status,
              amount: booking.customerPayableAmount ?? booking.escrowAmount));
      if (!_current(revision)) return;
      final document =
          ReportDocument(bytes: bytes, idempotencyKey: const Uuid().v4());
      await ref.read(reportDraftStoreProvider).save(_owner!, arg, document);
      if (!_current(revision)) return;
      _document = document;
      state = ReportState(
          phase: ReportPhase.idle, hasDocument: true, page: state.page);
      ref.read(appAnalyticsProvider).log(AnalyticsEvent.reportGenerated,
          {'report_type': 'booking_summary', 'file_size_bytes': bytes.length});
    } catch (error) {
      _fail(revision, error);
    }
  }

  Future<void> upload() async {
    if (state.busy || _document == null) return;
    final revision = _revision;
    state = state.copyWith(phase: ReportPhase.uploading, progress: 0);
    try {
      // Persist an uncertain intent BEFORE dispatch, so closing the screen cannot lose retry identity.
      final pendingDocument = _document!.withOutcome();
      await ref
          .read(reportDraftStoreProvider)
          .save(_owner!, arg, pendingDocument);
      if (!_current(revision)) return;
      _document = pendingDocument;
      final request = ref
          .read(reportsRepositoryProvider)
          .upload(arg, _document!, (sent, total) {
        if (!_current(revision) || total <= 0) return;
        final progress = (sent / total).clamp(0.0, 1.0);
        state = state.copyWith(
            phase:
                progress >= 1 ? ReportPhase.processing : ReportPhase.uploading,
            progress: progress);
      });
      _upload = request;
      final receipt = await request.result;
      if (!_current(revision)) return;
      if (!receipt.completed) throw StateError('report incomplete');
      final completedDocument = _document!.withOutcome(completedId: receipt.id);
      await ref
          .read(reportDraftStoreProvider)
          .save(_owner!, arg, completedDocument);
      if (!_current(revision)) return;
      _document = completedDocument;
      state = state.copyWith(
          phase: ReportPhase.idle,
          progress: 1,
          reportId: receipt.id,
          uncertain: false);
      _refreshHistory();
      ref
          .read(appAnalyticsProvider)
          .logOnce(AnalyticsEvent.fileUploadCompleted, receipt.id, {
        'upload_purpose': 'booking_report',
        'file_type': 'pdf',
        'file_size_bytes': receipt.sizeBytes
      });
    } catch (error) {
      if (!_current(revision)) return;
      final api = error is AppApiException ? error : null;
      final uncertain = api == null ||
          api.isTransportFailure ||
          api.isCancelled ||
          api.statusCode == 409 && api.code == 'report.upload_pending' ||
          (api.statusCode ?? 0) >= 500;
      state = state.copyWith(
          phase: ReportPhase.idle,
          uncertain: uncertain,
          error: uncertain
              ? 'Chưa xác nhận được kết quả. Kiểm tra kết nối và thử lại cùng tệp để đối soát.'
              : api.message);
      if (!uncertain) {
        _document = _document!.withOutcome(attempted: false);
        try {
          await ref
              .read(reportDraftStoreProvider)
              .save(_owner!, arg, _document!);
        } catch (_) {}
        if (!_current(revision)) return;
        ref.read(appAnalyticsProvider).logOnce(AnalyticsEvent.fileUploadFailed,
            '${_document!.idempotencyKey}:${_errorCategory(api)}', {
          'upload_purpose': 'booking_report',
          'error_code': _errorCategory(api)
        });
      }
      _refreshHistory();
    } finally {
      if (_current(revision)) _upload = null;
    }
  }

  String _errorCategory(AppApiException? error) => switch (error?.statusCode) {
        400 || 413 => 'invalid_file',
        401 => 'unauthenticated',
        403 || 404 => 'access_denied',
        409 => 'conflict',
        429 => 'rate_limited',
        _ => 'request_rejected'
      };

  Future<void> preview({String? reportId}) async {
    if (state.busy) return;
    final revision = _revision;
    state = state.copyWith(phase: ReportPhase.previewing);
    try {
      final bytes = reportId == null
          ? _document?.bytes
          : await ref.read(reportsRepositoryProvider).download(reportId);
      if (!_current(revision) || bytes == null) return;
      await ref.read(reportDocumentsProvider).preview(bytes);
      if (_current(revision)) state = state.copyWith(phase: ReportPhase.idle);
    } catch (error) {
      _fail(revision, error);
    }
  }

  void refreshHistory() => _refreshHistory();
  void _refreshHistory() {
    ref.read(reportHistoryRevisionProvider(arg).notifier).state++;
  }

  void changePage(int page) {
    if (page < 1 || state.busy) return;
    state = state.copyWith(page: page);
  }

  void _fail(int revision, Object error) {
    if (!_current(revision)) return;
    state = state.copyWith(
        phase: ReportPhase.idle,
        error: error is AppApiException
            ? error.message
            : 'Chưa hoàn tất thao tác. Vui lòng thử lại.');
  }
}

final reportHistoryRevisionProvider =
    StateProvider.autoDispose.family<int, String>((_, __) => 0);

final reportHistoryProvider =
    FutureProvider.autoDispose.family((ref, String booking) {
  ref.watch(reportHistoryRevisionProvider(booking));
  final page =
      ref.watch(reportsControllerProvider(booking).select((s) => s.page));
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  return ref.watch(reportsRepositoryProvider).list(booking, page: page);
});
