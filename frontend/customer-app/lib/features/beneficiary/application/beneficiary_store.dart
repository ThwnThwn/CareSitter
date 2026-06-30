import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_data.dart';

final beneficiaryStoreProvider =
    NotifierProvider<BeneficiaryStore, List<MockBeneficiary>>(
  BeneficiaryStore.new,
);

class BeneficiaryStore extends Notifier<List<MockBeneficiary>> {
  @override
  List<MockBeneficiary> build() => [...MockData.beneficiaries];

  MockBeneficiary add({
    required String name,
    required int age,
    required String relation,
    required String condition,
    required String careLevel,
    required String notes,
    required String address,
    required List<EmergencyContact> emergencyContacts,
  }) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(3)
        .join();
    final beneficiary = MockBeneficiary(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      age: age,
      relation: relation,
      avatarInitial: initials,
      condition: condition.isEmpty ? 'Chưa có ghi chú' : condition,
      careLevel: careLevel,
      notes: notes.trim(),
      address: address.trim(),
      emergencyContacts: [...emergencyContacts],
    );
    state = [...state, beneficiary];
    return beneficiary;
  }
}
