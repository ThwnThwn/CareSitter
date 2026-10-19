import 'dart:async';

import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_realtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins and leaves only the booking group owned by the chat', () async {
    final hub = _FakeHub();
    final realtime = BookingChatRealtime(hub);

    await realtime.connect('booking-a');
    await realtime.connect('booking-a');
    await realtime.connect('booking-b');
    await realtime.disconnect();

    expect(hub.joined, ['booking-a', 'booking-b']);
    expect(hub.left, ['booking-a', 'booking-b']);
    expect(hub.disconnectCalls, 0);
    realtime.dispose();
  });
}

class _FakeHub implements CareSignalRService {
  final _chat = StreamController<String>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final List<String> joined = [];
  final List<String> left = [];
  int disconnectCalls = 0;

  @override
  Stream<String> get bookingChatStream => _chat.stream;

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> joinBooking(String bookingId) async => joined.add(bookingId);

  @override
  Future<void> leaveBooking(String bookingId) async => left.add(bookingId);

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
