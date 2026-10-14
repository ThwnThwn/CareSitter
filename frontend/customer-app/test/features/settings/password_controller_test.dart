import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/password_controller.dart';

void main() {
  test('password write locks synchronously and stays locked until logout',
      () async {
    final response = Completer<bool>();
    var writes = 0;
    var busy = false;
    final controller = PasswordController(
      isCurrent: () => true,
      write: ({required currentPassword, required newPassword, cancellation}) {
        writes++;
        return response.future;
      },
    );
    addTearDown(controller.dispose);
    controller.addListener((value) => busy = value);
    final first =
        controller.changePassword(currentPassword: 'old', newPassword: 'new');
    expect(busy, isTrue);
    expect(
        await controller.changePassword(
            currentPassword: 'old', newPassword: 'new'),
        isFalse);
    expect(writes, 1);
    response.complete(true);
    expect(await first, isTrue);
    expect(busy, isTrue);
    expect(
        await controller.changePassword(
            currentPassword: 'old', newPassword: 'new'),
        isFalse);
    expect(writes, 1);
  });

  test('dispose cancels transport and ignores a late successful response',
      () async {
    final response = Completer<bool>();
    final cancellation = ApiCancellation();
    final controller = PasswordController(
        isCurrent: () => true,
        cancellation: cancellation,
        write: (
                {required currentPassword,
                required newPassword,
                cancellation}) =>
            response.future);
    final pending =
        controller.changePassword(currentPassword: 'old', newPassword: 'new');
    controller.dispose();
    expect(cancellation.isCancelled, isTrue);
    response.complete(true);
    expect(await pending, isFalse);
  });

  test('session replacement ignores success and prevents another write',
      () async {
    var current = true;
    var writes = 0;
    final response = Completer<bool>();
    final controller = PasswordController(
        isCurrent: () => current,
        write: (
            {required currentPassword, required newPassword, cancellation}) {
          writes++;
          return response.future;
        });
    addTearDown(controller.dispose);
    final pending =
        controller.changePassword(currentPassword: 'old', newPassword: 'new');
    current = false;
    response.complete(true);
    expect(await pending, isFalse);
    expect(
        await controller.changePassword(
            currentPassword: 'old', newPassword: 'new'),
        isFalse);
    expect(writes, 1);
  });

  test('failed response releases the lock and an API error remains retryable',
      () async {
    var writes = 0;
    var busy = false;
    final controller = PasswordController(
        isCurrent: () => true,
        write: (
            {required currentPassword,
            required newPassword,
            cancellation}) async {
          writes++;
          if (writes == 1) return false;
          if (writes == 2) throw StateError('server rejection');
          return true;
        });
    addTearDown(controller.dispose);
    controller.addListener((value) => busy = value);
    expect(
        await controller.changePassword(
            currentPassword: 'old', newPassword: 'new'),
        isFalse);
    expect(busy, isFalse);
    await expectLater(
        controller.changePassword(currentPassword: 'old', newPassword: 'new'),
        throwsStateError);
    expect(busy, isFalse);
    expect(
        await controller.changePassword(
            currentPassword: 'old', newPassword: 'new'),
        isTrue);
    expect(writes, 3);
  });
}
