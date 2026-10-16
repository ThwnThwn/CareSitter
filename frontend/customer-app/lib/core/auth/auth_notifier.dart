import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';

const _storage = FlutterSecureStorage();

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kPhone = 'phone';

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  final Set<Future<void> Function()> _logoutCleanups = {};
  int _sessionGeneration = 0;
  int? _loggingOutGeneration;
  bool _rememberSession = false;
  Future<void> _storageWrites = Future<void>.value();
  int get sessionGeneration => _sessionGeneration;
  Future<void> _persist(Future<void> Function() action) {
    final operation = _storageWrites.then((_) => action(),
        onError: (Object error, StackTrace stack) => action());
    _storageWrites = operation;
    return operation;
  }

  @override
  Future<AuthState> build() async {
    return _loadFromStorage();
  }

  Future<AuthState> _loadFromStorage() async {
    final token = await _storage.read(key: _kAccessToken);
    final refresh = await _storage.read(key: _kRefreshToken);
    final userId = await _storage.read(key: _kUserId);
    final phone = await _storage.read(key: _kPhone);
    if (token != null && userId != null) {
      _rememberSession = true;
      return AuthState(
        accessToken: token,
        refreshToken: refresh,
        userId: userId,
        phone: phone,
        isAuthenticated: true,
      );
    }
    _rememberSession = false;
    return const AuthState.initial();
  }

  Future<void> login({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String phone,
    bool rememberSession = true,
  }) async {
    final generation = ++_sessionGeneration;
    await _persist(() async {
      if (generation != _sessionGeneration) return;
      _rememberSession = rememberSession;
      if (rememberSession) {
        await _storage.write(key: _kAccessToken, value: accessToken);
        await _storage.write(key: _kRefreshToken, value: refreshToken);
        await _storage.write(key: _kUserId, value: userId);
        await _storage.write(key: _kPhone, value: phone);
      } else {
        await _clearPersistedSession();
      }
      if (generation == _sessionGeneration) {
        state = AsyncData(AuthState(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            phone: phone,
            isAuthenticated: true));
      }
    });
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final generation = _sessionGeneration;
    final previous = state.value;
    if (previous?.isAuthenticated != true) return;
    await _persist(() async {
      if (generation != _sessionGeneration ||
          state.value?.refreshToken != previous!.refreshToken) {
        return;
      }
      if (_rememberSession) {
        await _storage.write(key: _kAccessToken, value: accessToken);
        await _storage.write(key: _kRefreshToken, value: refreshToken);
      }
      if (generation == _sessionGeneration) {
        state = AsyncData(previous.copyWith(
            accessToken: accessToken, refreshToken: refreshToken));
      }
    });
  }

  Future<void> logout() async {
    if (_loggingOutGeneration == _sessionGeneration) return;
    final generation = ++_sessionGeneration;
    _loggingOutGeneration = generation;
    try {
      for (final cleanup in List.of(_logoutCleanups)) {
        try {
          await cleanup();
        } catch (_) {
          // Logout must still clear the local session when remote cleanup fails.
        }
      }
      await _persist(() async {
        if (generation != _sessionGeneration) return;
        await _clearPersistedSession();
        _rememberSession = false;
        if (generation == _sessionGeneration) {
          state = const AsyncData(AuthState.initial());
        }
      });
    } finally {
      if (_loggingOutGeneration == generation) _loggingOutGeneration = null;
    }
  }

  Future<void> _clearPersistedSession() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kPhone);
  }

  void registerLogoutCleanup(Future<void> Function() cleanup) {
    _logoutCleanups.add(cleanup);
  }

  void unregisterLogoutCleanup(Future<void> Function() cleanup) {
    _logoutCleanups.remove(cleanup);
  }

  String? get accessToken => state.value?.accessToken;
  String? get refreshToken => state.value?.refreshToken;
}
