import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';

const contacts = [
  EmergencyContact(name: 'A', phone: '0901234567', relationship: 'Con'),
  EmergencyContact(name: 'B', phone: '0911234567', relationship: 'Con')
];

void main() {
  test('same phone with country prefix is rejected before any write', () async {
    var writes = 0;
    final controller =
        BeneficiaryFormController(saveRecord: (s, n, d, notes, c, a) async {
      writes++;
      return 'saved';
    });
    addTearDown(controller.dispose);
    controller.addressId = 'address';
    final result = await controller
        .save(name: 'Profile', birthDate: null, notes: '', contacts: [
      contacts.first,
      const EmergencyContact(
          name: 'B', phone: '+84901234567', relationship: 'Con')
    ]);
    expect(result, isA<BeneficiaryFormMessage>());
    expect(writes, 0);
  });

  test('saving locks before asynchronous work and preserves draft on error',
      () async {
    final pending = Completer<String>();
    var writes = 0;
    final controller =
        BeneficiaryFormController(saveRecord: (s, n, d, notes, c, a) {
      writes++;
      return pending.future;
    });
    addTearDown(controller.dispose);
    controller.addressId = 'address';
    controller.careLevel = 'Nặng';
    controller.addCondition('Cần hỗ trợ đi lại');
    final first = controller.save(
        name: 'Profile', birthDate: null, notes: '', contacts: contacts);
    expect(
        await controller.save(
            name: 'Profile', birthDate: null, notes: '', contacts: contacts),
        isA<BeneficiaryFormIgnored>());
    expect(writes, 1);
    pending.completeError(StateError('offline'));
    expect(await first, isA<BeneficiaryFormMessage>());
    expect(controller.value.saving, isFalse);
    expect(controller.value.careLevel, 'Nặng');
    expect(controller.value.conditions, ['Cần hỗ trợ đi lại']);
    expect(() => controller.value.conditions.add('mutation'),
        throwsUnsupportedError);
  });

  test('disposing flow drops a late saved response', () async {
    final pending = Completer<String>();
    final controller = BeneficiaryFormController(
        saveRecord: (s, n, d, notes, c, a) => pending.future);
    final states = <BeneficiaryFormState>[];
    controller.addListener(states.add);
    controller.addressId = 'address';
    final first = controller.save(
        name: 'Profile', birthDate: null, notes: '', contacts: contacts);
    controller.dispose();
    final count = states.length;
    pending.complete('saved');
    expect(await first, isA<BeneficiaryFormIgnored>());
    expect(states.length, count);
  });
}
