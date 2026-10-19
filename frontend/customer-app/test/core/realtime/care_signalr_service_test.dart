import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_realtime.dart';

class TestAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      accessToken: 'local-test', userId: 'customer', isAuthenticated: true);
}

class FakeHub implements HubConnection {
  @override
  HubConnectionState? state = HubConnectionState.Disconnected;
  bool failStart = false;
  int stopCalls = 0;
  Object? joinResult = 'ok';
  Completer<Object?>? joinGate;
  final calls = <String>[];
  ReconnectedCallback? reconnected;
  ReconnectingCallback? reconnecting;
  ClosedCallback? closed;
  final handlers = <String, MethodInvocationFunc>{};
  @override
  Future<void> start() async {
    if (failStart) throw Exception('test offline');
    state = HubConnectionState.Connected;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    state = HubConnectionState.Disconnected;
    closed?.call();
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object>? args}) async {
    calls.add('$methodName:${args?.first}');
    if (methodName == 'JoinBookingGroup') {
      if (joinGate != null) return await joinGate!.future;
      return joinResult;
    }
    return null;
  }

  @override
  void on(String methodName, MethodInvocationFunc newMethod) {
    handlers[methodName] = newMethod;
  }

  @override
  void onclose(ClosedCallback callback) {
    closed = callback;
  }

  @override
  void onreconnecting(ReconnectingCallback callback) {
    reconnecting = callback;
  }

  @override
  void onreconnected(ReconnectedCallback callback) {
    reconnected = callback;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<(ProviderContainer, CareSignalRService)> setup(FakeHub hub) async {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(TestAuth.new),
      careSignalRProvider.overrideWith(
          (ref) => CareSignalRService(ref, connectionFactory: () => hub)),
    ]);
    await container.read(authStateProvider.future);
    return (container, container.read(careSignalRProvider));
  }

  test('Reconnect notification waits for the booking group to be joined',
      () async {
    final hub = FakeHub();
    final (container, service) = await setup(hub);
    final events = <SignalRConnectionState>[];
    final subscription = service.lifecycleStream.listen(events.add);
    await service.joinBooking('booking');
    hub.state = HubConnectionState.Reconnecting;
    hub.reconnecting!.call();
    hub.joinGate = Completer<Object?>();
    hub.state = HubConnectionState.Connected;
    hub.reconnected!.call(connectionId: 'new');
    await Future<void>.delayed(Duration.zero);
    expect(events, isNot(contains(SignalRConnectionState.reconnected)));
    expect(service.isReady, false);
    hub.joinGate!.complete('ok');
    await Future<void>.delayed(Duration.zero);
    expect(events.last, SignalRConnectionState.reconnected);
    expect(service.isReady, true);
    await subscription.cancel();
    await service.dispose();
    container.dispose();
  });

  test('Every non-ok group response leaves tracking in fallback mode',
      () async {
    for (final result in [
      'unauthorized',
      'invalid_booking_id',
      'service_not_configured',
      null
    ]) {
      final hub = FakeHub()..joinResult = result;
      final (container, service) = await setup(hub);
      await service.joinBooking('booking');
      expect(service.isConnected, true);
      expect(service.isReady, false);
      await service.dispose();
      container.dispose();
    }
  });

  test('Multiple viewers retain the group until the last screen leaves',
      () async {
    final hub = FakeHub();
    final (container, service) = await setup(hub);
    await service.joinBooking('booking');
    await service.joinBooking('booking');
    await service.leaveBooking('booking');
    expect(hub.calls.where((call) => call.startsWith('Leave')), isEmpty);
    await service.leaveBooking('booking');
    expect(hub.calls.where((call) => call.startsWith('Leave')).length, 1);
    await service.dispose();
    container.dispose();
  });

  test('Booking Chat uses the shared hub without owning its connection',
      () async {
    final hub = FakeHub();
    final (container, service) = await setup(hub);
    final realtime = BookingChatRealtime(service);
    final changes = <void>[];
    final subscription = realtime.changes.listen(changes.add);

    await realtime.connect('booking');
    hub.handlers['BookingChatChanged']!.call([
      {'bookingId': 'another-booking'}
    ]);
    hub.handlers['BookingChatChanged']!.call([
      {'bookingId': 'booking'}
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(changes, hasLength(1));

    await realtime.disconnect();
    expect(hub.state, HubConnectionState.Connected);
    expect(hub.stopCalls, 0);

    await subscription.cancel();
    realtime.dispose();
    await service.dispose();
    container.dispose();
  });

  test('Initial connection failure retries and remembers the requested booking',
      () async {
    final hub = FakeHub()..failStart = true;
    final (container, service) = await setup(hub);
    await service.joinBooking('booking');
    expect(service.isReady, false);
    hub.failStart = false;
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(service.isReady, true);
    expect(hub.calls, contains('JoinBookingGroup:booking'));
    await service.dispose();
    container.dispose();
  });
}
