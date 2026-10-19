import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/signalr_client.dart';

class _TestAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      accessToken: 'local-test', userId: 'caregiver', isAuthenticated: true);
}

class _FakeHub implements HubConnection {
  @override
  HubConnectionState? state = HubConnectionState.Disconnected;
  final calls = <String>[];
  ClosedCallback? closed;

  @override
  Future<void> start() async => state = HubConnectionState.Connected;

  @override
  Future<void> stop() async {
    state = HubConnectionState.Disconnected;
    closed?.call();
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object>? args}) async {
    calls.add('$methodName:${args?.first}');
    return methodName == 'JoinBookingGroup' ? 'ok' : null;
  }

  @override
  void on(String methodName, MethodInvocationFunc newMethod) {}

  @override
  void onclose(ClosedCallback callback) => closed = callback;

  @override
  void onreconnecting(ReconnectingCallback callback) {}

  @override
  void onreconnected(ReconnectedCallback callback) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('multiple consumers retain a booking group until the last one leaves',
      () async {
    final hub = _FakeHub();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_TestAuth.new),
      careSignalRProvider.overrideWith(
          (ref) => CareSignalRService(ref, connectionFactory: () => hub)),
    ]);
    await container.read(authStateProvider.future);
    final service = container.read(careSignalRProvider);

    await service.joinBooking('booking');
    await service.joinBooking('booking');
    await service.leaveBooking('booking');
    expect(hub.calls.where((call) => call.startsWith('Leave')), isEmpty);
    await service.leaveBooking('booking');
    expect(hub.calls.where((call) => call.startsWith('Leave')), hasLength(1));

    await service.dispose();
    container.dispose();
  });
}
