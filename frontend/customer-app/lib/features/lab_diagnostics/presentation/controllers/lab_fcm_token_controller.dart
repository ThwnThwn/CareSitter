import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/diagnostics/lab_demo_policy.dart';
import 'package:caresitter_customer/core/push/push_messaging_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final labFcmTokenControllerProvider =
    Provider<LabFcmTokenController>(LabFcmTokenController.new);

class LabFcmTokenController {
  const LabFcmTokenController(this._ref);

  final Ref _ref;

  static bool get enabled =>
      kDebugMode &&
      LabDemoPolicy.enabled &&
      defaultTargetPlatform == TargetPlatform.android;

  Future<String?> readAsync() async {
    if (!enabled ||
        _ref.read(authStateProvider).valueOrNull?.isAuthenticated != true) {
      return null;
    }

    final auth = _ref.read(authStateProvider.notifier);
    final generation = auth.sessionGeneration;
    final gateway = _ref.read(pushMessagingGatewayProvider);
    final token =
        await _fetchToken(gateway).timeout(const Duration(seconds: 12));
    if (auth.sessionGeneration != generation) return null;
    return token == null || token.isEmpty ? null : token;
  }

  Future<String?> _fetchToken(PushMessagingGateway gateway) async {
    if (!await gateway.initialize()) return null;
    return gateway.token();
  }
}
