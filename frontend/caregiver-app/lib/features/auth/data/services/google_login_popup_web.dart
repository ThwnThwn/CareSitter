import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:web/web.dart' as web;

import '../../domain/google_login_popup.dart';

GoogleLoginPopup createPopup(Uri startUri) => _WebGoogleLoginPopup(startUri);

class _WebGoogleLoginPopup implements GoogleLoginPopup {
  _WebGoogleLoginPopup(this._startUri);

  static const _cancelled = AppApiException(
    message: 'Đã đóng cửa sổ đăng nhập Google.',
    isCancelled: true,
  );

  final Uri _startUri;
  Completer<String>? _pending;

  @override
  Future<String> requestIdToken() async {
    if (_pending != null) return _pending!.future;
    final random = Random.secure();
    final requestId = List.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final url = _startUri.replace(queryParameters: {
      'origin': web.window.location.origin,
      'requestId': requestId,
    });
    final result = Completer<String>();
    final popup = web.window.open(url.toString(), 'caregiver-google-$requestId',
        'popup=yes,width=500,height=650');
    if (popup == null) {
      throw const AppApiException(
        message:
            'Trình duyệt đã chặn cửa sổ Google. Hãy cho phép cửa sổ bật lên rồi thử lại.',
      );
    }
    _pending = result;

    final listener = ((web.MessageEvent message) {
      // Check origin and JS reference identity before reading the message.
      if (result.isCompleted ||
          message.origin != _startUri.origin ||
          !identical(message.source, popup)) {
        return;
      }
      final data = message.data.dartify();
      if (data is! Map ||
          data['type'] != 'caresitter:google-auth' ||
          data['requestId'] != requestId) {
        return;
      }
      final token = data['idToken'];
      if (data['error'] == null && token is String && token.trim().isNotEmpty) {
        result.complete(token);
      } else {
        result.completeError(switch (data['error']) {
          'cancelled' => _cancelled,
          'configuration' => const AppApiException(
              message: 'Đăng nhập Google chưa được cấu hình trên máy chủ.'),
          _ => const AppApiException(
              message:
                  'Google chưa xác thực được tài khoản. Vui lòng thử lại.'),
        });
      }
    }).toJS;
    web.window.addEventListener('message', listener);
    final monitor = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (popup.closed && !result.isCompleted) result.completeError(_cancelled);
    });
    try {
      return await result.future.timeout(const Duration(minutes: 5),
          onTimeout: () {
        throw const AppApiException(
            message: 'Phiên đăng nhập Google đã hết thời gian.');
      });
    } finally {
      monitor.cancel();
      web.window.removeEventListener('message', listener);
      if (!popup.closed) popup.close();
      _pending = null;
    }
  }

  @override
  void dispose() {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(_cancelled);
    }
  }
}
