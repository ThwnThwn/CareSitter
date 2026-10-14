import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/registration_controller.dart';

Future<bool> submit(RegistrationController controller) => controller.submit(
    fullName: 'Người kiểm thử',
    email: 'caregiver@example.com',
    phone: '0901234567',
    password: 'Password1',
    confirmPassword: 'Password1');

void main() {
  test('agreement and in-flight lock protect registration', () async {
    var writes = 0;
    final pending = Completer<void>();
    final controller = RegistrationController(({
      required fullName,
      required email,
      required phone,
      required password,
      required confirmPassword,
    }) {
      writes++;
      return pending.future;
    });
    addTearDown(controller.dispose);
    expect(await submit(controller), isFalse);
    expect(writes, 0);
    controller.setAgreement(true);
    final first = submit(controller);
    expect(await submit(controller), isFalse);
    expect(writes, 1);
    pending.complete();
    expect(await first, isTrue);
  });

  test('failure retains agreement and allows retry', () async {
    var writes = 0;
    final controller = RegistrationController(({
      required fullName,
      required email,
      required phone,
      required password,
      required confirmPassword,
    }) async {
      if (++writes == 1) throw StateError('temporary failure');
    });
    addTearDown(controller.dispose);
    controller.setAgreement(true);
    expect(await submit(controller), isFalse);
    expect(controller.state.busy, isFalse);
    expect(controller.state.agreed, isTrue);
    expect(controller.state.error, isNotNull);
    expect(await submit(controller), isTrue);
  });

  test('disposal suppresses a late successful registration', () async {
    final pending = Completer<void>();
    final controller = RegistrationController(({
      required fullName,
      required email,
      required phone,
      required password,
      required confirmPassword,
    }) =>
        pending.future);
    controller.setAgreement(true);
    final first = submit(controller);
    controller.dispose();
    pending.complete();
    expect(await first, isFalse);
  });
}
