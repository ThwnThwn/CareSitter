import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late StreamSubscription<HttpRequest> subscription;
  late ProviderContainer container;
  late Dio http;
  late Completer<_ReceivedRequest> received;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    received = Completer<_ReceivedRequest>();
    subscription = server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      received.complete(_ReceivedRequest(
        request.method,
        request.uri.path,
        request.headers.contentType?.mimeType,
        body,
      ));
      // CancelBookingRequest cho phép reason null, nhưng API yêu cầu JSON body.
      request.response.statusCode = body.isEmpty ? 400 : 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(body.isEmpty
          ? '{"title":"A non-empty request body is required."}'
          : jsonEncode({
              'id': 'booking-1',
              'status': 'cancelled',
              'cancelledAt': '2026-10-08T09:00:00Z',
              'updatedAt': '2026-10-08T09:00:00Z',
              'createdAt': '2026-10-01T00:00:00Z',
              'syncVersion': 2,
            }));
      await request.response.close();
    });
    http = Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
    ));
    container = ProviderContainer(overrides: [
      dioClientProvider.overrideWith((ref) => _HttpDioClient(ref, http)),
    ]);
  });

  tearDown(() async {
    container.dispose();
    http.close(force: true);
    await subscription.cancel();
    await server.close(force: true);
  });

  test('cancellation without a reason still sends a JSON request body',
      () async {
    final booking = await container
        .read(bookingRepositoryProvider)
        .cancelBooking('booking-1');

    final request = await received.future;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/bookings/booking-1/cancel');
    expect(request.contentType, 'application/json');
    expect(jsonDecode(request.body), {'reason': null});
    expect(booking.id, 'booking-1');
    expect(booking.status, 'cancelled');
    expect(booking.cancelledAt?.toUtc(), DateTime.utc(2026, 10, 8, 9));
    expect(booking.updatedAt.toUtc(), DateTime.utc(2026, 10, 8, 9));
    expect(booking.syncVersion, 2);
  });

  test('cancellation includes the supplied reason in the JSON body', () async {
    await container.read(bookingRepositoryProvider).cancelBooking(
          'booking-1',
          reason: 'Đổi kế hoạch',
        );

    final request = await received.future;
    expect(request.contentType, 'application/json');
    expect(jsonDecode(request.body), {'reason': 'Đổi kế hoạch'});
  });
}

class _HttpDioClient extends DioClient {
  final Dio http;

  _HttpDioClient(super.ref, this.http);

  @override
  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      http.post<T>(path, data: data);
}

class _ReceivedRequest {
  final String method;
  final String path;
  final String? contentType;
  final String body;

  const _ReceivedRequest(this.method, this.path, this.contentType, this.body);
}
