import 'package:caresitter_customer/features/reports/data/repositories/reports_repository.dart';
import 'package:caresitter_customer/features/reports/domain/report_document.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(isAuthenticated: false);
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  int status = 409;
  String body =
      '{"title":"booking.caregiver.schedule_conflict","detail":"Trùng lịch"}';
  bool transportFailure = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    lastRequest = options;
    if (transportFailure) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.receiveTimeout);
    }
    return ResponseBody.fromString(body, status, headers: {
      'content-type': ['application/json'],
      'retry-after': ['20']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ProviderContainer container;
  late _Adapter server;
  late DioClient client;
  setUp(() async {
    server = _Adapter();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioClientProvider.overrideWith((ref) => DioClient(ref, adapter: server))
    ]);
    await container.read(authStateProvider.future);
    client = container.read(dioClientProvider);
  });
  tearDown(() => container.dispose());
  test('knowledge timeout override does not change ordinary API requests',
      () async {
    server.status = 200;
    server.body = '{}';
    await client.getCancelable('/nutrition/knowledge',
        cancelToken: CancelToken(),
        receiveTimeout: const Duration(seconds: 45));
    expect(server.lastRequest!.receiveTimeout, const Duration(seconds: 45));
    expect(server.lastRequest!.connectTimeout, const Duration(seconds: 45));
    await client.get('/test');
    expect(server.lastRequest!.receiveTimeout, const Duration(seconds: 30));
    expect(server.lastRequest!.connectTimeout, const Duration(seconds: 10));
  });
  test('ngrok API requests skip the browser interstitial only on ngrok hosts',
      () async {
    final ngrokContainer = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioClientProvider.overrideWith((ref) => DioClient(ref,
          baseUrl: 'https://demo.ngrok-free.dev/api/v1', adapter: server)),
    ]);
    addTearDown(ngrokContainer.dispose);
    await ngrokContainer.read(authStateProvider.future);
    final ngrok = ngrokContainer.read(dioClientProvider);
    await expectLater(
        ngrok.get('/nutrition/capabilities'), throwsA(isA<AppApiException>()));
    expect(server.lastRequest?.headers['ngrok-skip-browser-warning'], '1');

    await expectLater(
        client.get('/nutrition/capabilities'), throwsA(isA<AppApiException>()));
    expect(
        server.lastRequest?.headers.containsKey('ngrok-skip-browser-warning'),
        isFalse);
  });
  test(
      'HTTP failure exposes AppApiException with business code and retry delay',
      () async {
    await expectLater(
        client.get('/test'),
        throwsA(isA<AppApiException>()
            .having(
                (e) => e.code, 'code', 'booking.caregiver.schedule_conflict')
            .having((e) => e.message, 'message', 'Trùng lịch')
            .having((e) => e.retryAfterSeconds, 'retry delay', 20)
            .having(
                (e) => e.outcomeMayBeUnknown, 'definitive rejection', false)));
  });
  test('lost response and cancellation remain distinct', () async {
    server.transportFailure = true;
    await expectLater(
        client.post('/test'),
        throwsA(isA<AppApiException>()
            .having((e) => e.outcomeMayBeUnknown, 'unknown outcome', true)));
    final token = CancelToken()..cancel();
    await expectLater(
        client.getCancelable('/test', cancelToken: token),
        throwsA(isA<AppApiException>()
            .having((e) => e.isCancelled, 'cancelled', true)
            .having((e) => e.isTransportFailure, 'transport failure', false)));
  });
  test(
      'booking serializes UTC and keeps the operation key outside its JSON body',
      () async {
    server.status = 201;
    server.body = '{"id":"booking"}';
    final draft = BookingDraft(
        beneficiaryId: 'person',
        serviceTypeId: 'service',
        addressId: 'address',
        scheduledStart: DateTime.utc(2026, 10, 12, 1),
        scheduledEnd: DateTime.utc(2026, 10, 12, 3),
        idempotencyKey: 'stable-operation');
    await BookingRepository(client).createBooking(draft);
    final request = server.lastRequest!;
    expect(request.headers['Idempotency-Key'], 'stable-operation');
    expect(request.data['scheduledStart'], '2026-10-12T01:00:00.000Z');
    expect(request.data.containsKey('idempotencyKey'), isFalse);
  });
  test('an unreadable successful POST is still an unknown write outcome',
      () async {
    server.status = 201;
    server.body = '[]';
    await expectLater(
        client.post<Map<String, dynamic>>('/bookings'),
        throwsA(isA<AppApiException>()
            .having((e) => e.outcomeMayBeUnknown, 'unknown outcome', true)));
  });
  test('only the explicit self-not-found error means absence', () async {
    server.status = 404;
    server.body = '{"title":"beneficiary.self_not_found"}';
    final repository = BeneficiaryRepository(client);
    expect(await repository.getSelf(), isNull);
    server.body = '{"title":"beneficiary.not_found"}';
    await expectLater(repository.getSelf(), throwsA(isA<AppApiException>()));
  });
  test('report upload uses PDF multipart and a stable header outside the body',
      () async {
    server.status = 200;
    server.body =
        '{"id":"report","bookingId":"booking","status":"COMPLETED","sizeBytes":3,"createdAt":"2026-11-06T00:00:00Z"}';
    final request = ReportsRepository(client).upload(
        'booking',
        ReportDocument(
            bytes: Uint8List.fromList([1, 2, 3]), idempotencyKey: 'stable-key'),
        (_, __) {});
    final receipt = await request.result;
    expect(receipt.completed, isTrue);
    expect(server.lastRequest!.path, '/bookings/booking/reports');
    expect(server.lastRequest!.headers['Idempotency-Key'], 'stable-key');
    final form = server.lastRequest!.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'caresitter-report.pdf');
    expect(form.files.single.value.contentType.toString(), 'application/pdf');
  });
}
