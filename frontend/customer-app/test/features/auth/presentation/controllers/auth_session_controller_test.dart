import 'package:caresitter_customer/features/auth/data/services/firebase_identity_bridge.dart';
import 'package:caresitter_customer/features/auth/domain/firebase_identity_bridge.dart';
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
  bool failGoogle = false;
  String? firebaseToken;
  AuthResponse? detached;
  @override
  Future<AuthResponse> loginWithFirebaseGoogleToken(String token) async {
    firebaseToken = token;
    if (failGoogle) {
      throw const AppApiException(message: 'Unavailable', statusCode: 503);
    }
    return pending == null ? response : await pending!.future;
  }

  @override
  Future<void> revokeDetachedSession(AuthResponse response) async {
    detached = response;
  }

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

class _Firebase implements FirebaseIdentityBridge {
  String? boundOwner;
  int exchanges = 0, signouts = 0;
  @override
  Future<String?> exchangeGoogleToken(String token) async {
    exchanges++;
    return 'firebase-token';
  }

  @override
  Future<void> bindOwner(String owner) async {
    boundOwner = owner;
  }

  @override
  Future<bool> reconcileSession(String? owner) async => true;
  @override
  Future<void> signOut() async {
    signouts++;
    boundOwner = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late ProviderContainer container;
  late _Repository repository;
  late _Firebase firebase;
  late Map<String, String> storageValues;
  setUp(() async {
    storageValues = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final args = call.arguments as Map? ?? {};
      if (call.method == 'read') return storageValues[args['key']];
      if (call.method == 'write') {
        storageValues[args['key'] as String] = args['value'] as String;
      }
      if (call.method == 'delete') {
        storageValues.remove(args['key'] as String);
      }
      if (call.method == 'deleteAll') storageValues.clear();
      return null;
    });
    repository = _Repository();
    firebase = _Firebase();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      firebaseIdentityBridgeProvider.overrideWithValue(firebase),
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
    expect(storageValues['access_token'], 'test-access');
  });
  test('login without remember keeps auth only in the current process',
      () async {
    await container.read(authSessionControllerProvider).login(
          const LoginRequest(
              email: 'test@example.com', password: 'test-password'),
          rememberSession: false,
        );

    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
    expect(container.read(authStateProvider.notifier).refreshToken,
        'test-refresh');
    expect(storageValues, isEmpty);

    await container.read(authStateProvider.notifier).updateTokens(
          accessToken: 'rotated-access',
          refreshToken: 'rotated-refresh',
        );
    expect(storageValues, isEmpty);
    expect(container.read(authStateProvider.notifier).refreshToken,
        'rotated-refresh');
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
  test(
      'native Google exchange sends Firebase ID token and binds the accepted CareSitter owner',
      () async {
    await container
        .read(authSessionControllerProvider)
        .loginWithGoogleIdToken('google-token');
    expect(firebase.exchanges, 1);
    expect(repository.firebaseToken, 'firebase-token');
    expect(firebase.boundOwner, 'owner');
    expect(container.read(authStateProvider).value!.userId, 'owner');
  });
  test(
      'backend failure clears the partial Firebase login without accepting a CareSitter session',
      () async {
    repository.failGoogle = true;
    await expectLater(
        container
            .read(authSessionControllerProvider)
            .loginWithGoogleIdToken('google-token'),
        throwsA(isA<AppApiException>()));
    expect(firebase.signouts, 1);
    expect(container.read(authStateProvider).value!.isAuthenticated, isFalse);
  });
  test(
      'logout during a pending Google exchange revokes the detached backend session',
      () async {
    repository.pending = Completer<AuthResponse>();
    final signingIn = container
        .read(authSessionControllerProvider)
        .loginWithGoogleIdToken('google-token');
    final check = expectLater(signingIn, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await container.read(authSessionControllerProvider).logout();
    repository.pending!.complete(response);
    await check;
    expect(repository.detached, response);
    expect(firebase.boundOwner, isNull);
    expect(container.read(authStateProvider).value!.isAuthenticated, isFalse);
  });
  test(
      'logout invalidates a pending password attempt before it can publish a session',
      () async {
    repository.pending = Completer<AuthResponse>();
    final signingIn = container.read(authSessionControllerProvider).login(
        const LoginRequest(
            email: 'demo@example.com', password: 'test-password'));
    final check = expectLater(signingIn, throwsStateError);
    await container.read(authSessionControllerProvider).logout();
    repository.pending!.complete(response);
    await check;
    expect(container.read(authStateProvider).value!.isAuthenticated, isFalse);
  });
}
