import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/data/repositories/auth_repository.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

const response = AuthResponse(
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    userId: 'owner',
    roles: ['CUSTOMER'],
    displayName: 'An');

class _Client implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends AuthRepository {
  _Repository() : super(_Client());
  Completer<AuthResponse>? pending;
  bool failLogout = false;
  String? revoked;
  @override
  Future<AuthResponse> login(LoginRequest request) async =>
      pending == null ? response : await pending!.future;
  @override
  Future<AuthResponse> refresh(String token) async => response;
  @override
  Future<void> logout({String? refreshToken}) async {
    revoked = refreshToken;
    if (failLogout) throw const AppApiException(message: 'Server tạm dừng');
  }
}

class _Profile extends ProfileStore {
  _Profile(super.ref);
  @override
  Future<void> fetchProfile() async {}
}

class _Google implements GoogleIdentityGateway {
  @override
  Stream<GoogleIdentityCredential> get credentials => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> authenticate() async {}
  @override
  Future<void> clearLocalSelection() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late ProviderContainer container;
  late _Repository repository;
  setUp(() async {
    final values = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final args = call.arguments as Map? ?? {};
      if (call.method == 'read') return values[args['key']];
      if (call.method == 'write') {
        values[args['key'] as String] = args['value'] as String;
      }
      if (call.method == 'deleteAll') values.clear();
      return null;
    });
    repository = _Repository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      profileStoreProvider.overrideWith((ref) => _Profile(ref)),
      googleIdentityGatewayProvider.overrideWithValue(_Google())
    ]);
    await container.read(authStateProvider.future);
  });
  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });
  test('the session controller publishes auth and profile after login',
      () async {
    await container.read(authSessionControllerProvider).login(
        const LoginRequest(
            email: 'test@example.com', password: 'test-password'));
    expect(container.read(authStateProvider).value!.userId, 'owner');
    expect(container.read(profileStoreProvider).name, 'An');
  });
  test('a late login cannot overwrite a newer owner', () async {
    repository.pending = Completer<AuthResponse>();
    final loggingIn = container.read(authSessionControllerProvider).login(
        const LoginRequest(
            email: 'test@example.com', password: 'test-password'));
    final checked = expectLater(loggingIn, throwsStateError);
    await container.read(authStateProvider.notifier).login(
        accessToken: 'new-test-access',
        refreshToken: 'new-test-refresh',
        userId: 'new-owner',
        phone: '0900000000');
    container
        .read(profileStoreProvider.notifier)
        .setFromAuth(name: 'New owner');
    repository.pending!.complete(response);
    await checked;
    expect(container.read(authStateProvider).value!.userId, 'new-owner');
    expect(container.read(profileStoreProvider).name, 'New owner');
  });
  test(
      'logout revokes the refreshed token and clears local state if the server fails',
      () async {
    await container.read(authStateProvider.notifier).login(
        accessToken: 'old-test-access',
        refreshToken: 'old-test-refresh',
        userId: 'owner',
        phone: '0900000000');
    container.read(profileStoreProvider.notifier).setFromAuth(name: 'An');
    repository.failLogout = true;
    await container.read(authSessionControllerProvider).logout();
    expect(repository.revoked, 'test-refresh');
    expect(container.read(authStateProvider).value!.isAuthenticated, isFalse);
    expect(container.read(profileStoreProvider).name, isEmpty);
  });
}
