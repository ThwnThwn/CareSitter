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
  bool _isLoggingOut = false;

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
      return AuthState(
        accessToken: token,
        refreshToken: refresh,
        userId: userId,
        phone: phone,
        isAuthenticated: true,
      );
    }
    return const AuthState.initial();
  }

  Future<void> login({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String phone,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kPhone, value: phone);
    state = AsyncData(AuthState(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      phone: phone,
      isAuthenticated: true,
    ));
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    state = AsyncData(state.value!.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    ));
  }

  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      for (final cleanup in List.of(_logoutCleanups)) {
        try {
          await cleanup();
        } catch (_) {
          // Logout must still clear the local session when remote cleanup fails.
        }
      }
      await _storage.deleteAll();
      state = const AsyncData(AuthState.initial());
    } finally {
      _isLoggingOut = false;
    }
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
