import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/reports/data/models/firebase_report_session.dart';
import 'package:caresitter_customer/features/reports/data/repositories/reports_repository.dart';
import 'package:caresitter_customer/features/reports/data/services/firebase_report_storage_service.dart';
import 'package:caresitter_customer/features/reports/domain/report_document.dart';
import 'package:caresitter_customer/features/reports/domain/report_request.dart';

const owner = '11111111-1111-1111-1111-111111111111';
const id = '22222222-2222-2222-2222-222222222222';
final bytes =
    Uint8List.fromList(utf8.encode('%PDF-1.7\nsynthetic fixture\n%%EOF\n'));
final document = ReportDocument(bytes: bytes, idempotencyKey: 'stable-key');
Map<String, dynamic> receipt([String status = 'COMPLETED']) => {
      'id': id,
      'bookingId': 'booking',
      'status': status,
      'sizeBytes': bytes.length,
      'createdAt': '2026-11-11T00:00:00Z',
    };
Map<String, dynamic> session() => {
      'report': receipt('PENDING'),
      'uid': owner,
      'projectId': 'demo-caresitter',
      'bucket': 'demo-caresitter.firebasestorage.app',
      'objectPath': 'reports/$owner/${id.replaceAll('-', '')}.pdf',
      'customToken': 'synthetic',
      'expiresAtMs':
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    };

class Client implements DioClient {
  Map<String, dynamic> intent = session();
  final requests = <Map<String, dynamic>>[];
  Completer<Response<Map<String, dynamic>>>? preparing;
  Object? completionError;
  Completer<Response<Map<String, dynamic>>>? formResponse;
  FormData? form;
  CancelToken? formCancellation;
  String? formKey;
  String? formPath;
  @override
  Future<Response<T>> postForm<T>(String path, FormData data,
      {CancelToken? cancelToken,
      ProgressCallback? onSendProgress,
      String? idempotencyKey}) async {
    form = data;
    formPath = path;
    formKey = idempotencyKey;
    formCancellation = cancelToken;
    onSendProgress?.call(bytes.length, bytes.length);
    if (formResponse != null) {
      return (await formResponse!.future) as Response<T>;
    }
    return Response<T>(
        data: receipt() as T, requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> postCancelable<T>(String path,
      {dynamic data, required CancelToken cancelToken}) async {
    requests.add({'path': path, 'data': data, 'cancelToken': cancelToken});
    if (path.endsWith('firebase-session')) {
      if (preparing != null) return (await preparing!.future) as Response<T>;
      return Response<T>(
          data: intent as T, requestOptions: RequestOptions(path: path));
    }
    if (completionError != null) throw completionError!;
    return Response<T>(
        data: receipt() as T, requestOptions: RequestOptions(path: path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Storage extends FirebaseReportStorageService {
  int uploads = 0;
  bool cancelled = false;
  Completer<void>? pending;
  @override
  ReportRequest<void> upload(FirebaseReportSession session, Uint8List bytes,
      String checksum, void Function(int, int) progress) {
    uploads++;
    progress(bytes.length, bytes.length);
    return ReportRequest(
        pending?.future ?? Future.value(), () => cancelled = true);
  }
}

void main() {
  late Client client;
  late Storage storage;
  late ReportsRepository repository;
  setUp(() {
    client = Client();
    storage = Storage();
    repository = ReportsRepository(client,
        owner: owner, storage: storage, firebaseStorageEnabled: true);
  });
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
      'default uploads through the existing Cloudinary API without a Firebase session',
      () async {
    final current = ReportsRepository(client, storage: storage);
    var sent = 0;
    final saved = await current
        .upload('booking', document, (value, _) => sent = value)
        .result;
    expect(saved.completed, isTrue);
    expect(client.formPath, '/bookings/booking/reports');
    expect(client.formKey, document.idempotencyKey);
    final file = client.form!.files.single;
    expect(file.key, 'file');
    expect(file.value.filename, 'caresitter-report.pdf');
    expect(file.value.contentType.toString(), 'application/pdf');
    expect(file.value.length, bytes.length);
    expect(sent, bytes.length);
    expect(client.requests, isEmpty);
    expect(storage.uploads, 0);
  });
  test(
      'Cloudinary upload stays pending at 100 percent until the server confirms',
      () async {
    client.formResponse = Completer<Response<Map<String, dynamic>>>();
    final current = ReportsRepository(client, storage: storage);
    var completed = false;
    final request = current.upload('booking', document, (_, __) {});
    request.result.then((_) => completed = true);
    await settle();
    expect(completed, isFalse);
    client.formResponse!
        .complete(Response(data: receipt(), requestOptions: RequestOptions()));
    expect((await request.result).completed, isTrue);
  });
  test(
      'Cloudinary cancellation and retry preserve the existing idempotency key',
      () async {
    client.formResponse = Completer<Response<Map<String, dynamic>>>();
    final current = ReportsRepository(client);
    final request = current.upload('booking', document, (_, __) {});
    request.cancel();
    expect(client.formCancellation!.isCancelled, isTrue);
    client.formResponse!
        .complete(Response(data: receipt(), requestOptions: RequestOptions()));
    await request.result;
    final originalKey = client.formKey;
    client.formResponse = null;
    await current.upload('booking', document, (_, __) {}).result;
    expect(client.formKey, originalKey);
    expect(client.requests, isEmpty);
  });

  test(
      'direct upload sends intent hash and only succeeds after server completion',
      () async {
    storage.pending = Completer<void>();
    var sent = 0;
    final request =
        repository.upload('booking', document, (value, _) => sent = value);
    await settle();
    expect(sent, bytes.length);
    expect(client.requests.length, 1);
    var completed = false;
    request.result.then((_) => completed = true);
    expect(completed, isFalse);
    storage.pending!.complete();
    expect((await request.result).completed, isTrue);
    expect(client.requests.last['path'], '/reports/$id/firebase-completion');
    expect(client.requests.first['data']['idempotencyKey'],
        document.idempotencyKey);
    expect(client.requests.first['data']['checksum'], hasLength(64));
  });
  test('completed replay does not upload a second object', () async {
    client.intent['report'] = receipt();
    client.intent['customToken'] = null;
    expect((await repository.upload('booking', document, (_, __) {}).result).id,
        id);
    expect(storage.uploads, 0);
    expect(client.requests.length, 1);
  });
  test('foreign owner or object path is rejected before SDK access', () async {
    for (final changed in [
      {'uid': 'other'},
      {'objectPath': 'reports/other/file.pdf'}
    ]) {
      client.intent = {...session(), ...changed};
      await expectLater(
          repository.upload('booking', document, (_, __) {}).result,
          throwsA(isA<AppApiException>()
              .having((e) => e.statusCode, 'status', 403)));
    }
    expect(storage.uploads, 0);
  });
  test('leaving during prepare prevents late Firebase upload', () async {
    client.preparing = Completer<Response<Map<String, dynamic>>>();
    final request = repository.upload('booking', document, (_, __) {});
    final check = expectLater(
        request.result,
        throwsA(isA<AppApiException>()
            .having((e) => e.isCancelled, 'cancelled', true)));
    request.cancel();
    client.preparing!
        .complete(Response(data: session(), requestOptions: RequestOptions()));
    await check;
    expect(storage.uploads, 0);
  });
  test('leaving during SDK upload cancels task and prevents backend completion',
      () async {
    storage.pending = Completer<void>();
    final request = repository.upload('booking', document, (_, __) {});
    final check = expectLater(
        request.result,
        throwsA(isA<AppApiException>()
            .having((e) => e.isCancelled, 'cancelled', true)));
    await settle();
    request.cancel();
    storage.pending!.complete();
    await check;
    expect(storage.cancelled, isTrue);
    expect(client.requests.length, 1);
  });
  test('lost completion response retries with the same durable intent key',
      () async {
    client.completionError = const AppApiException(message: 'offline');
    await expectLater(repository.upload('booking', document, (_, __) {}).result,
        throwsA(isA<AppApiException>()));
    client.completionError = null;
    client.intent['report'] = receipt();
    await repository.upload('booking', document, (_, __) {}).result;
    final intents = client.requests
        .where((r) => (r['path'] as String).endsWith('firebase-session'));
    expect(intents.map((r) => r['data']['idempotencyKey']).toSet(),
        {'stable-key'});
    expect(storage.uploads, 1);
  });
  test('Firebase permission and offline errors remain distinguishable', () {
    final denied = FirebaseReportStorageService.mapError(
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'));
    final offline = FirebaseReportStorageService.mapError(FirebaseException(
        plugin: 'firebase_storage', code: 'retry-limit-exceeded'));
    expect(denied.statusCode, 403);
    expect(offline.isTransportFailure, isTrue);
  });
}
