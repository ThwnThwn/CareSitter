import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_controller.dart';

class _Actions implements RecoveryController {
  Completer<RecoveryChallenge>? pending;
  int requests = 0, verifies = 0, resets = 0;
  @override
  Future<RecoveryChallenge> request(String email) {
    requests++;
    return pending?.future ??
        Future.value(const RecoveryChallenge('challenge', 120, 30, 'Sent'));
  }

  @override
  Future<RecoveryGrant> verify(String id, String code) async {
    verifies++;
    return const RecoveryGrant('grant', 60);
  }

  @override
  Future<void> reset(String token, String password, String confirmation) async {
    resets++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  test(
      'request lock prevents double send and restart discards a late challenge',
      () async {
    final actions = _Actions()..pending = Completer<RecoveryChallenge>();
    final controller = PasswordRecoveryController(actions);
    final states = <PasswordRecoveryState>[];
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    final first = controller.request('email@example.com');
    expect(await controller.request('email@example.com'), isFalse);
    expect(actions.requests, 1);
    controller.restart();
    actions.pending!.complete(const RecoveryChallenge('old', 120, 30, 'Sent'));
    expect(await first, isFalse);
    expect(states.last.step, 0);
    expect(states.last.challengeId, isNull);
  });

  test('resend is blocked during cooldown and expired code is not submitted',
      () async {
    var now = DateTime.utc(2026, 10, 12);
    final actions = _Actions();
    final controller = PasswordRecoveryController(actions, clock: () => now);
    final states = <PasswordRecoveryState>[];
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    await controller.request('email@example.com');
    expect(
        await controller.request('email@example.com', resend: true), isFalse);
    now = now.add(const Duration(seconds: 121));
    expect(
        await controller.submit(code: '123456', password: '', confirmation: ''),
        isFalse);
    expect(actions.verifies, 0);
    expect(states.last.error, contains('hết hạn'));
  });

  test(
      'expired grant cannot reset password and restarting removes grant access',
      () async {
    var now = DateTime.utc(2026, 10, 12);
    final actions = _Actions();
    final controller = PasswordRecoveryController(actions, clock: () => now);
    final states = <PasswordRecoveryState>[];
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    await controller.request('email@example.com');
    await controller.submit(code: '123456', password: '', confirmation: '');
    expect(states.last.step, 2);
    now = now.add(const Duration(seconds: 61));
    expect(
        await controller.submit(
            code: '', password: 'Password1', confirmation: 'Password1'),
        isFalse);
    expect(actions.resets, 0);
    controller.restart();
    expect(
        await controller.submit(
            code: '', password: 'Password1', confirmation: 'Password1'),
        isFalse);
    expect(actions.resets, 0);
  });
}
