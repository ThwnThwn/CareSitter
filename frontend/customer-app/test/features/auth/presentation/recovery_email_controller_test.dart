import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/auth/data/models/recovery_email_model.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class _Actions implements RecoveryController {
  final pending = Completer<RecoveryChallenge>();
  int requests = 0;
  bool revoke = false;
  @override
  Future<RecoveryChallenge> requestEmail(String email, String? password) {
    requests++;
    return pending.future;
  }

  @override
  Future<RecoveryEmailModel> emailProfile() async =>
      const RecoveryEmailModel(email: 'old@example.com', hasPassword: true);
  @override
  Future<RecoveryEmailModel> confirmEmailProfile(
          String id, String code) async =>
      RecoveryEmailModel(email: 'new@example.com', sessionsRevoked: revoke);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  test('change info drops an old challenge and duplicate request is blocked',
      () async {
    final actions = _Actions();
    final controller = RecoveryEmailController(actions, logout: () async {});
    final states = <RecoveryEmailState>[];
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    await controller.load();
    final first = controller.request('new@example.com', 'Password1');
    expect(await controller.request('new@example.com', 'Password1'), isFalse);
    controller.changeInfo();
    actions.pending.complete(const RecoveryChallenge('old', 120, 30, 'Sent'));
    expect(await first, isFalse);
    expect(actions.requests, 1);
    expect(states.last.challengeId, isNull);
    expect(states.last.currentEmail, 'old@example.com');
  });
  test('revoked sessions trigger logout before sign-in result', () async {
    final actions = _Actions()..revoke = true;
    var logouts = 0;
    final controller = RecoveryEmailController(actions, logout: () async {
      logouts++;
    });
    addTearDown(controller.dispose);
    actions.pending.complete(const RecoveryChallenge('new', 120, 30, 'Sent'));
    await controller.request('new@example.com', 'Password1');
    expect(await controller.confirm('123456'), RecoveryEmailResult.signIn);
    expect(logouts, 1);
  });
}
