import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:caresitter_customer/core/config/env_config.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';

final googleIdentityGatewayProvider = Provider<GoogleIdentityGateway>(
  (ref) => GoogleSignInGateway(),
);

final googleIdentityInitializationProvider = FutureProvider<void>(
  (ref) => ref.watch(googleIdentityGatewayProvider).initialize(),
);

class GoogleSignInGateway implements GoogleIdentityGateway {
  GoogleSignInGateway({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  @override
  Stream<GoogleIdentityCredential> get credentials =>
      _googleSignIn.authenticationEvents.transform(
        StreamTransformer.fromHandlers(
          handleData: (event, sink) {
            if (event is! GoogleSignInAuthenticationEventSignIn) return;

            final idToken = event.user.authentication.idToken?.trim();
            if (idToken == null || idToken.isEmpty) {
              sink.addError(const GoogleIdentityException(
                GoogleIdentityFailureCode.missingIdToken,
                'Google không trả về ID token để đăng nhập.',
              ));
              return;
            }
            sink.add(GoogleIdentityCredential(idToken: idToken));
          },
          handleError: (error, stackTrace, sink) {
            sink.addError(
              error is GoogleSignInException ? _mapException(error) : error,
              stackTrace,
            );
          },
        ),
      );

  @override
  Future<void> initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    final webClientId = EnvConfig.googleWebClientId.trim();
    if (webClientId.isEmpty) {
      throw const GoogleIdentityException(
        GoogleIdentityFailureCode.configuration,
        'Thiếu GOOGLE_WEB_CLIENT_ID. Đây phải là OAuth Web Client ID dùng '
        'chung với backend CareSitter.',
      );
    }

    String? platformClientId;
    if (kIsWeb) {
      platformClientId = webClientId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      platformClientId = EnvConfig.googleIosClientId.trim();
      if (platformClientId.isEmpty) {
        throw const GoogleIdentityException(
          GoogleIdentityFailureCode.configuration,
          'Thiếu GOOGLE_IOS_CLIENT_ID cho ứng dụng iOS/macOS.',
        );
      }
    }

    try {
      await _googleSignIn.initialize(
        clientId: platformClientId,
        serverClientId: webClientId,
      );
    } on GoogleSignInException catch (error) {
      throw _mapException(error);
    } catch (error) {
      throw GoogleIdentityException(
        GoogleIdentityFailureCode.configuration,
        'Không thể khởi tạo Google Sign-In: $error',
      );
    }
  }

  @override
  Future<void> authenticate() async {
    await initialize();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleIdentityException(
        GoogleIdentityFailureCode.unsupportedPlatform,
        'Nền tảng này yêu cầu nút đăng nhập chính thức của Google.',
      );
    }

    try {
      // Clear only the app-local Google selection so every explicit login can
      // present the account chooser. This does not sign the user out of Google.
      await _googleSignIn.signOut();
      await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      throw _mapException(error);
    }
  }

  @override
  Future<void> clearLocalSelection() async {
    final initialization = _initialization;
    if (initialization == null) return;

    try {
      await initialization;
      await _googleSignIn.signOut();
    } catch (_) {
      // CareSitter already owns the authenticated session at this point.
      // Failure to clear Google's local choice must not invalidate that JWT.
    }
  }

  GoogleIdentityException _mapException(GoogleSignInException error) {
    final code = switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        GoogleIdentityFailureCode.cancelled,
      GoogleSignInExceptionCode.clientConfigurationError =>
        GoogleIdentityFailureCode.configuration,
      GoogleSignInExceptionCode.uiUnavailable =>
        GoogleIdentityFailureCode.unsupportedPlatform,
      _ => GoogleIdentityFailureCode.unknown,
    };

    return GoogleIdentityException(
      code,
      error.description ?? 'Đăng nhập Google không thành công.',
    );
  }
}
