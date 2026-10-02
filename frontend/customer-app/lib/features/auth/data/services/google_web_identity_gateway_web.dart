import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import 'package:caresitter_customer/core/config/env_config.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';

GoogleIdentityGateway createGoogleWebIdentityGateway(Ref ref) {
  final gateway = GoogleWebIdentityGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
}

class GoogleWebIdentityGateway implements GoogleIdentityGateway {
  final _credentials = StreamController<GoogleIdentityCredential>.broadcast();
  Completer<void>? _pending;
  web.Window? _popup;

  @override
  Stream<GoogleIdentityCredential> get credentials => _credentials.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> authenticate() async {
    if (_pending != null) return;
    final pending = Completer<void>();
    _pending = pending;
    final random = Random.secure();
    final requestId = List.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final apiBase = Uri.parse(EnvConfig.apiBaseUrl);
    final endpoint = Uri.parse(
      '${EnvConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/auth/google/customer/web/start',
    ).replace(queryParameters: {
      'origin': web.window.location.origin,
      'requestId': requestId,
    });

    void fail(GoogleIdentityFailureCode code, String message) {
      if (!pending.isCompleted) {
        pending.completeError(GoogleIdentityException(code, message));
      }
    }

    final listener = ((web.Event event) {
      final message = event as web.MessageEvent;
      // Both the backend origin and the exact popup must match. A tab or frame
      // cannot log this browser in by posting someone else's token.
      if (message.origin != apiBase.origin ||
          _popup == null ||
          // `Window.operator ==` tries to read a Dart equality property from
          // the cross-origin Google popup and the browser correctly blocks it.
          // Identity comparison maps to JavaScript's safe reference equality.
          !identical(message.source, _popup) ||
          pending.isCompleted) {
        return;
      }
      final data = message.data.dartify();
      if (data is! Map ||
          data['type'] != 'caresitter:google-auth' ||
          data['requestId'] != requestId) {
        return;
      }
      final error = data['error'];
      if (error != null) {
        fail(
          switch (error) {
            'cancelled' => GoogleIdentityFailureCode.cancelled,
            'configuration' => GoogleIdentityFailureCode.configuration,
            'missing_token' => GoogleIdentityFailureCode.missingIdToken,
            _ => GoogleIdentityFailureCode.unknown,
          },
          'Không thể hoàn tất đăng nhập Google.',
        );
        return;
      }
      final token = data['idToken'];
      if (token is! String || token.trim().isEmpty) {
        fail(GoogleIdentityFailureCode.missingIdToken,
            'Google không trả về thông tin xác thực.');
        return;
      }
      _credentials.add(GoogleIdentityCredential(idToken: token));
      pending.complete();
    }).toJS;

    web.window.addEventListener('message', listener);
    Timer? closedTimer;
    try {
      // Open synchronously from the click, before awaiting any network work.
      _popup = web.window.open(endpoint.toString(), 'google-$requestId',
          'popup=yes,width=500,height=650');
      if (_popup == null) {
        throw const GoogleIdentityException(
          GoogleIdentityFailureCode.unsupportedPlatform,
          'Trình duyệt đã chặn cửa sổ Google. Hãy cho phép cửa sổ bật lên rồi thử lại.',
        );
      }
      closedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        try {
          if (_popup?.closed == true) {
            fail(GoogleIdentityFailureCode.cancelled, 'Đã đóng cửa sổ Google.');
          }
        } catch (_) {
          // Some account pages restrict cross-origin window inspection.
        }
      });
      await pending.future.timeout(const Duration(minutes: 5), onTimeout: () {
        throw const GoogleIdentityException(GoogleIdentityFailureCode.unknown,
            'Phiên đăng nhập Google đã hết thời gian.');
      });
    } finally {
      closedTimer?.cancel();
      web.window.removeEventListener('message', listener);
      _popup?.close();
      _popup = null;
      _pending = null;
    }
  }

  @override
  Future<void> clearLocalSelection() async {
    // Each new backend challenge uses prompt=select_account. No Google session
    // or CareSitter session is stored by this browser transport.
  }

  void dispose() {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const GoogleIdentityException(
          GoogleIdentityFailureCode.cancelled, 'Đã rời màn hình đăng nhập.'));
    }
    _popup?.close();
    unawaited(_credentials.close());
  }
}
