import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/caregiver_controller.dart';

class TestAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);
}

class ControlledClient implements DioClient {
  final requests = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    final request = Completer<Map<String, dynamic>>();
    requests.add(request);
    return Response<T>(
        data: (await request.future) as T,
        requestOptions: RequestOptions(path: path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Refresh failure preserves visible data and exposes retryable error',
      () async {
    final client = ControlledClient();
    final container = ProviderContainer(overrides: [
      dioClientProvider.overrideWithValue(client),
      authStateProvider.overrideWith(TestAuth.new),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final first = container.read(caregiverStoreProvider.future);
    client.requests.single.complete({
      'items': [
        {'id': 'caregiver-1', 'fullName': 'An'}
      ]
    });
    await first;
    final refresh = container.read(caregiverStoreProvider.notifier).refresh();
    expect(container.read(caregiverStoreProvider).valueOrNull!.single.id,
        'caregiver-1');
    expect(container.read(caregiverStoreProvider).isLoading, isTrue);
    client.requests.last.completeError(Exception('offline'));
    await refresh;
    expect(container.read(caregiverStoreProvider).hasError, isTrue);
    expect(container.read(caregiverStoreProvider).valueOrNull!.single.id,
        'caregiver-1');
  });
}
