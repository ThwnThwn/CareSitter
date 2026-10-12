import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/auth/data/models/auth_user_model.dart';
import 'package:caregiver_app/features/auth/data/repositories/auth_repository.dart';

final authSessionControllerProvider = Provider(AuthSessionController.new);

class AuthSessionController {
  AuthSessionController(this.ref) {
    ref.listen(authStateProvider, (before, after) {
      if (before?.valueOrNull?.userId != after.valueOrNull?.userId ||
          before?.valueOrNull?.isAuthenticated !=
              after.valueOrNull?.isAuthenticated) {
        _version++;
      }
    });
    ref.onDispose(() => _active = false);
  }
  final Ref ref;
  int _version = 0, _attempt = 0;
  bool _active = true;
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  Future<void> loginWithPassword(String identifier, String password) =>
      _login(() => _repository.loginWithPassword(identifier, password));
  Future<void> loginWithOtp(String identifier, String otp) =>
      _login(() => _repository.loginWithOtp(identifier, otp));
  Future<void> requestOtp(String email) => _repository.requestOtp(email);
  Future<void> _login(Future<AuthUserModel> Function() action) async {
    final version = _version, attempt = ++_attempt;
    final user = await action();
    if (!_active || version != _version || attempt != _attempt) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    if (!user.hasRole('CAREGIVER')) {
      throw const AppApiException(
          message:
              'Tài khoản này không có quyền đăng nhập ứng dụng Caregiver.');
    }
    await ref.read(authStateProvider.notifier).login(
        accessToken: user.accessToken,
        refreshToken: user.refreshToken,
        userId: user.userId,
        phone: user.displayName,
        roles: user.roles);
  }

  Future<void> logout() async {
    final auth = ref.read(authStateProvider.notifier);
    final version = _version;
    bool current() => _active && version == _version;
    var token = auth.refreshToken;
    try {
      if (token != null && token.isNotEmpty) {
        try {
          final refreshed = await _repository.refresh(token);
          if (!current()) return;
          if (refreshed.accessToken.isNotEmpty &&
              refreshed.refreshToken.isNotEmpty) {
            await auth.updateTokens(
                accessToken: refreshed.accessToken,
                refreshToken: refreshed.refreshToken);
            token = refreshed.refreshToken;
          }
        } catch (_) {/* Phiên hết hạn vẫn được dọn local. */}
      }
      if (current()) await _repository.logout(refreshToken: token);
    } catch (_) {/* Mất kết nối vẫn cho phép đăng xuất local. */} finally {
      if (current()) await auth.logout();
    }
  }
}
