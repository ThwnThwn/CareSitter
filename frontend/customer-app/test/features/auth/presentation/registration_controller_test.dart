import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/registration_controller.dart';

void main() {
  test('agreement and submit lock protect registration', () async {
    final pending = Completer<void>();
    var writes = 0;
    final controller = RegistrationController((_) {
      writes++;
      return pending.future;
    });
    addTearDown(controller.dispose);
    const request = RegisterRequest(
        fullName: 'A',
        email: 'a@example.com',
        password: 'Password1',
        confirmPassword: 'Password1',
        phone: '0901234567');
    expect(await controller.submit(request), isFalse);
    expect(writes, 0);
    controller.setAgreement(true);
    final first = controller.submit(request);
    expect(await controller.submit(request), isFalse);
    expect(writes, 1);
    pending.complete();
    expect(await first, isTrue);
  });
}
