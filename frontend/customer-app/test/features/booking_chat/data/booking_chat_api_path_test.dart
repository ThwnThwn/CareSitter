import 'dart:convert';
import 'dart:typed_data';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking chat reaches versioned API routes with the configured base URL',
      () async {
    final server = _Server();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioClientProvider.overrideWith((ref) => DioClient(ref, adapter: server)),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final repository = BookingChatRepository(container.read(dioClientProvider));

    expect((await repository.metadata('booking')).featureEnabled, isTrue);
    expect((await repository.messages('booking')).items, isEmpty);
    expect(
        await repository.sendText('booking', 'epoch', 'Xin chào', 'text-key'),
        'message');
    expect(
        await repository.sendQuick('booking', 'epoch', 'hello', 1, 'quick-key'),
        'message');
    await repository.markRead('booking', 'epoch', 'message');
    await repository.reportMessage('booking', 'message', 'Lừa đảo hoặc spam');
    await repository.setBlocked('booking', true);
    await repository.messages('booking', afterCursor: 'fs:1:1:message');

    expect(server.requests.map((r) => '${r.method} ${r.uri.path}').toList(), [
      'GET /api/v1/bookings/booking/chat',
      'GET /api/v1/bookings/booking/chat/messages',
      'POST /api/v1/bookings/booking/chat/messages',
      'POST /api/v1/bookings/booking/chat/messages',
      'PUT /api/v1/bookings/booking/chat/read',
      'POST /api/v1/bookings/booking/chat/messages/message/reports',
      'PUT /api/v1/bookings/booking/chat/block',
      'GET /api/v1/bookings/booking/chat/messages/resume',
    ]);
    expect(server.requests[2].headers['Idempotency-Key'], 'text-key');
    expect(server.requests[3].headers['Idempotency-Key'], 'quick-key');
    expect(server.requests[5].data, {'reason': 'Lừa đảo hoặc spam'});
    expect(server.requests[6].data, {'blocked': true});
    expect(
        server.requests.last.uri.queryParameters['anchorMessageId'], 'message');
  });
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.initial();
}

class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = options.path.endsWith('/chat')
        ? {
            'bookingId': 'booking',
            'featureEnabled': true,
            'serverNow': '2026-10-28T00:00:00Z',
          }
        : options.method == 'GET'
            ? {'items': <dynamic>[]}
            : {'id': 'message'};
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}
