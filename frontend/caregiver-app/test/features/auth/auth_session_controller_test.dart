import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/auth/data/models/auth_user_model.dart';
import 'package:caregiver_app/features/auth/data/repositories/auth_repository.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/auth_session_controller.dart';

class _Client implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends AuthRepository {
  _Repository() : super(_Client());
  List<String> roles = ['CAREGIVER'];
  Completer<AuthUserModel>? pending;
  @override
  Future<AuthUserModel> loginWithPassword(
          String identifier, String password) async =>
      pending != null
          ? await pending!.future
          : AuthUserModel(
              accessToken: 'test-access',
              refreshToken: 'test-refresh',
              userId: 'owner',
              displayName: 'Caregiver',
              roles: roles);
}

class _Auth extends AuthNotifier {
  int logins = 0;
  @override
  Future<AuthState> build() async => const AuthState.initial();
  @override
  Future<void> login(
      {required String accessToken,
      required String refreshToken,
      required String userId,
      required String phone,
      required List<String> roles}) async {
    logins++;
    state = AsyncData(
        AuthState(userId: userId, isAuthenticated: true, roles: roles));
  }

  void switchOwner() => state = const AsyncData(AuthState(
      userId: 'new-owner', isAuthenticated: true, roles: ['CAREGIVER']));
}

void main() {
  late ProviderContainer container;
  late _Repository repository;
  late _Auth auth;
  setUp(() async {
    repository = _Repository();
    auth = _Auth();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(() => auth)
    ]);
    await container.read(authStateProvider.future);
  });
  tearDown(() => container.dispose());
  test('session controller accepts a caregiver and publishes the owner',
      () async {
    await container
        .read(authSessionControllerProvider)
        .loginWithPassword('test@example.com', 'test-password');
    expect(auth.logins, 1);
    expect(container.read(authStateProvider).value!.userId, 'owner');
  });
  test('a customer-only response never enters the caregiver session', () async {
    repository.roles = ['CUSTOMER'];
    await expectLater(
        container
            .read(authSessionControllerProvider)
            .loginWithPassword('test@example.com', 'test-password'),
        throwsA(isA<AppApiException>()));
    expect(auth.logins, 0);
  });
  test('a late response cannot replace a new owner', () async {
    repository.pending = Completer<AuthUserModel>();
    final login = container
        .read(authSessionControllerProvider)
        .loginWithPassword('test@example.com', 'test-password');
    final checked = expectLater(login, throwsStateError);
    auth.switchOwner();
    repository.pending!.complete(const AuthUserModel(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        userId: 'old-owner',
        displayName: 'Old',
        roles: ['CAREGIVER']));
    await checked;
    expect(auth.logins, 0);
    expect(container.read(authStateProvider).value!.userId, 'new-owner');
  });
}
