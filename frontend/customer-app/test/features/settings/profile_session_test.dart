import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/settings/data/repositories/profile_repository.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class _Auth extends AuthNotifier {
  int _version = 0;
  @override
  int get sessionGeneration => _version;
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'A', isAuthenticated: true);
  void switchUser() {
    _version++;
    state = const AsyncData(AuthState(userId: 'B', isAuthenticated: true));
  }
}

class _NoClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HTTP');
}

class _Profiles extends ProfileRepository {
  _Profiles() : super(_NoClient());
  final uploads = [Completer<bool>(), Completer<bool>()];
  int calls = 0;
  @override
  Future<UserProfile?> getProfile(UserProfile current) async => current;
  @override
  Future<bool> uploadAvatar(Uint8List bytes, String name) =>
      uploads[calls++].future;
}

void main() {
  test('late upload from old user cannot release the next user upload lock',
      () async {
    final repository = _Profiles();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      profileRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final store = container.read(profileStoreProvider.notifier);
    final first = store.uploadAvatar(Uint8List(1), 'first.png');
    expect(container.read(avatarUploadingProvider), isTrue);
    (container.read(authStateProvider.notifier) as _Auth).switchUser();
    expect(container.read(avatarUploadingProvider), isFalse);
    final second = store.uploadAvatar(Uint8List(1), 'second.png');
    repository.uploads.first.complete(true);
    expect(await first, isFalse);
    expect(container.read(avatarUploadingProvider), isTrue);
    repository.uploads.last.complete(true);
    expect(await second, isTrue);
    expect(container.read(avatarUploadingProvider), isFalse);
  });
}
