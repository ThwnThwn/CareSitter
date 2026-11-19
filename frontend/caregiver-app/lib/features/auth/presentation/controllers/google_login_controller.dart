import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/config/env_config.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/services/google_login_popup_factory.dart';
import '../../domain/google_login_popup.dart';
import 'auth_session_controller.dart';

final googleLoginControllerProvider =
    Provider.autoDispose<GoogleLoginController?>((ref) {
  if (!kIsWeb) return null;
  ref.watch(authStateProvider.select((state) =>
      (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
  final popup = createGoogleLoginPopup(EnvConfig.googleWebStartUri);
  if (popup == null) return null;
  final controller =
      GoogleLoginController(popup, ref.read(authSessionControllerProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

class GoogleLoginController {
  GoogleLoginController(this._popup, this._session);

  final GoogleLoginPopup _popup;
  final AuthSessionController _session;
  final _cancellation = ApiCancellation();

  Future<void> signIn() async {
    final idToken = await _popup.requestIdToken();
    if (_cancellation.isCancelled) {
      throw const AppApiException(
          message: 'Đã hủy đăng nhập.', isCancelled: true);
    }
    await _session.loginWithGoogle(idToken, _cancellation);
  }

  void dispose() {
    _cancellation.cancel();
    _popup.dispose();
  }
}
