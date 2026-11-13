import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import 'package:caresitter_customer/core/analytics/analytics_sink.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/reports/data/models/report_receipt.dart';
import 'package:caresitter_customer/features/reports/data/repositories/reports_repository.dart';
import 'package:caresitter_customer/features/reports/data/services/pdf_report_documents.dart';
import 'package:caresitter_customer/features/reports/data/services/report_draft_store.dart';
import 'package:caresitter_customer/features/reports/domain/report_document.dart';
import 'package:caresitter_customer/features/reports/domain/report_documents.dart';
import 'package:caresitter_customer/features/reports/domain/report_request.dart';
import 'package:caresitter_customer/features/reports/domain/report_summary.dart';
import 'package:caresitter_customer/features/reports/presentation/controllers/reports_controller.dart';

class Client implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Auth extends AuthNotifier {
  int epoch = 0;
  @override
  int get sessionGeneration => epoch;
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
  void switchOwner() {
    epoch++;
    state = const AsyncData(AuthState(userId: 'other', isAuthenticated: true));
  }
}

class Bookings extends BookingRepository {
  Bookings() : super(Client());
  @override
  Future<BookingModel> getBooking(String id) async => BookingModel(
      id: id,
      beneficiaryId: 'person',
      addressId: 'address',
      serviceTypeId: 'service',
      scheduledStart: DateTime.utc(2026, 11, 6),
      scheduledEnd: DateTime.utc(2026, 11, 6, 2),
      status: 'confirmed',
      escrowAmount: 100000,
      platformFeeAmount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026));
}

class Documents implements ReportDocuments {
  int generated = 0, previews = 0;
  @override
  Future<Uint8List> generate(ReportSummary summary) async {
    generated++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> preview(Uint8List bytes) async {
    previews++;
  }
}

class Drafts extends ReportDraftStore {
  final documents = <String, ReportDocument>{};
  Completer<ReportDocument?>? pendingRestore;
  @override
  Future<ReportDocument?> load(String owner, String booking) async {
    if (owner == 'owner' && pendingRestore != null) {
      return pendingRestore!.future;
    }
    return documents['$owner:$booking'];
  }

  @override
  Future<void> save(
      String owner, String booking, ReportDocument document) async {
    documents['$owner:$booking'] = document;
  }
}

class Reports extends ReportsRepository {
  Reports() : super(Client());
  Completer<ReportReceipt>? pending;
  void Function(int, int)? progress;
  final keys = <String>[];
  bool cancelled = false;
  @override
  Future<List<ReportReceipt>> list(String booking,
          {int page = 1, int pageSize = 20}) async =>
      [];
  @override
  ReportRequest<ReportReceipt> upload(String booking, ReportDocument document,
      void Function(int, int) onProgress) {
    keys.add(document.idempotencyKey);
    progress = onProgress;
    pending = Completer<ReportReceipt>();
    return ReportRequest(pending!.future, () => cancelled = true);
  }
}

class Sink implements AnalyticsSink {
  final events = <AnalyticsEvent>[];
  @override
  Future<void> setUserId(String? id) async {}
  @override
  Future<void> log(AnalyticsEvent event, Map<String, Object> parameters) async {
    events.add(event);
  }
}

void main() {
  late ProviderContainer container;
  late Reports repository;
  late Documents documents;
  late Drafts drafts;
  late Sink sink;
  final provider = reportsControllerProvider('booking');
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    repository = Reports();
    documents = Documents();
    drafts = Drafts();
    sink = Sink();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(Auth.new),
      bookingRepositoryProvider.overrideWithValue(Bookings()),
      reportsRepositoryProvider.overrideWithValue(repository),
      reportDocumentsProvider.overrideWithValue(documents),
      reportDraftStoreProvider.overrideWithValue(drafts),
      analyticsSinkProvider.overrideWithValue(sink)
    ]);
    await container.read(authStateProvider.future);
    container.listen(provider, (_, __) {});
    await settle();
  });
  tearDown(() => container.dispose());
  ReportReceipt receipt() => ReportReceipt(
      id: 'report',
      bookingId: 'booking',
      status: 'COMPLETED',
      sizeBytes: 3,
      createdAt: DateTime.utc(2026));

  test('100 percent transport waits for server receipt before showing success',
      () async {
    final controller = container.read(provider.notifier);
    await controller.generate();
    final upload = controller.upload();
    await settle();
    repository.progress!(3, 3);
    expect(container.read(provider).phase, ReportPhase.processing);
    expect(container.read(provider).reportId, isNull);
    expect(drafts.documents['owner:booking']!.attempted, isTrue);
    repository.pending!.complete(receipt());
    await upload;
    expect(container.read(provider).reportId, 'report');
    expect(drafts.documents['owner:booking']!.completedId, 'report');
    await container.read(appAnalyticsProvider).drained;
    expect(sink.events,
        [AnalyticsEvent.reportGenerated, AnalyticsEvent.fileUploadCompleted]);
  });
  test(
      'unknown network outcome preserves bytes and retry key across controller restart',
      () async {
    var controller = container.read(provider.notifier);
    await controller.generate();
    final upload = controller.upload();
    await settle();
    repository.pending!
        .completeError(const AppApiException(message: 'offline'));
    await upload;
    expect(container.read(provider).uncertain, isTrue);
    final oldKey = repository.keys.single;
    container.invalidate(provider);
    await settle();
    controller = container.read(provider.notifier);
    expect(container.read(provider).uncertain, isTrue);
    await controller.generate();
    expect(documents.generated, 1);
    final retry = controller.upload();
    await settle();
    expect(repository.keys.last, oldKey);
    repository.pending!.complete(receipt());
    await retry;
    expect(container.read(provider).uncertain, isFalse);
  });
  test('known access rejection emits failure without publishing success',
      () async {
    final controller = container.read(provider.notifier);
    await controller.generate();
    final upload = controller.upload();
    await settle();
    repository.pending!.completeError(
        const AppApiException(message: 'denied', statusCode: 403));
    await upload;
    expect(container.read(provider).reportId, isNull);
    expect(container.read(provider).uncertain, isFalse);
    await container.read(appAnalyticsProvider).drained;
    expect(sink.events, contains(AnalyticsEvent.fileUploadFailed));
    expect(sink.events, isNot(contains(AnalyticsEvent.fileUploadCompleted)));
  });
  test('switching owner cancels upload and ignores its late receipt', () async {
    final controller = container.read(provider.notifier);
    await controller.generate();
    final upload = controller.upload();
    await settle();
    (container.read(authStateProvider.notifier) as Auth).switchOwner();
    await settle();
    expect(repository.cancelled, isTrue);
    repository.pending!.complete(receipt());
    await upload;
    expect(container.read(provider).reportId, isNull);
    expect(container.read(provider).hasDocument, isFalse);
    await container.read(appAnalyticsProvider).drained;
    expect(sink.events, isNot(contains(AnalyticsEvent.fileUploadCompleted)));
  });
  test('late draft restore cannot replace the new owners document', () async {
    drafts.pendingRestore = Completer<ReportDocument?>();
    container.invalidate(provider);
    await settle();
    final nextDocument = ReportDocument(
        bytes: Uint8List.fromList([8, 9]), idempotencyKey: 'new-owner-key');
    drafts.documents['other:booking'] = nextDocument;
    (container.read(authStateProvider.notifier) as Auth).switchOwner();
    await settle();
    drafts.pendingRestore!.complete(ReportDocument(
        bytes: Uint8List.fromList([1]), idempotencyKey: 'old-owner-key'));
    await settle();
    final upload = container.read(provider.notifier).upload();
    await settle();
    expect(repository.keys.single, 'new-owner-key');
    repository.pending!.complete(receipt());
    await upload;
  });
}
