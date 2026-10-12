import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'missing health information stays unknown and is not copied from mobility notes',
      () {
    final profile = BeneficiaryModel.fromBackend({
      'id': 'profile',
      'fullName': 'Người thân',
      'mobilityNote': 'Cần hỗ trợ',
    });
    expect(profile.dateOfBirth, isNull);
    expect(profile.age, isNull);
    expect(profile.gender, isNull);
    expect(profile.condition, isEmpty);
    expect(profile.careLevel, isEmpty);
    expect(profile.allergies, isNull);
    expect(profile.mobilityNote, 'Cần hỗ trợ');
    final request =
        profile.copyWith(name: 'Tên mới').toProfileRequest(previous: profile);
    expect(request.keys, unorderedEquals(['FullName', 'DefaultAddressId']));
  });

  test(
      'age respects birthday and updating a name preserves the exact birth date and health data',
      () {
    final profile = BeneficiaryModel.fromBackend({
      'Id': 'profile',
      'FullName': 'Người thân',
      'DateOfBirth': '1950-12-23',
      'Gender': 'FEMALE',
      'Phone': '0901234567',
      'HealthHistory': {'note': 'Tiền sử'},
      'Allergies': ['test-allergen'],
      'ChronicConditions': ['test-condition'],
      'Medications': ['test-medication'],
    });
    expect(profile.ageAt(DateTime(2026, 12, 22)), 75);
    expect(profile.ageAt(DateTime(2026, 12, 23)), 76);
    final updated = profile.copyWith(name: 'Tên mới');
    expect(updated.dateOfBirth, DateTime(1950, 12, 23));
    expect(updated.gender, 'FEMALE');
    expect(updated.phone, profile.phone);
    expect(updated.healthHistory, profile.healthHistory);
    expect(updated.allergies, profile.allergies);
    expect(updated.chronicConditions, profile.chronicConditions);
    expect(updated.medications, profile.medications);
    expect(updated.toProfileRequest(previous: profile).keys,
        unorderedEquals(['FullName', 'DefaultAddressId']));
  });

  test(
      'birth date and gender edits are sent exactly, including an explicit clear',
      () {
    final profile = BeneficiaryModel.fromBackend(
        {'Id': 'profile', 'FullName': 'Người thân'});
    final updated =
        profile.copyWith(dateOfBirth: DateTime(1960, 2, 29), gender: 'FEMALE');
    final request = updated.toProfileRequest(previous: profile);
    expect(request['DateOfBirth'], '1960-02-29');
    expect(request['Gender'], 'FEMALE');
    expect(updated.toProfileRequest()['DateOfBirth'], '1960-02-29');
    final cleared = updated
        .copyWith(dateOfBirth: null, gender: null)
        .toProfileRequest(previous: updated);
    expect(cleared.containsKey('DateOfBirth'), isTrue);
    expect(cleared['DateOfBirth'], isNull);
    expect(cleared.containsKey('Gender'), isTrue);
    expect(cleared['Gender'], isNull);
  });

  test(
      'date entry accepts leap days but never silently normalizes an invalid date',
      () {
    expect(BirthDateField.parse('29/02/1960'), DateTime(1960, 2, 29));
    expect(BirthDateField.parse('29/02/1961'), isNull);
    expect(BirthDateField.parse('31/04/1960'), isNull);
    expect(BirthDateField.parse('00/01/1960'), isNull);
    expect(BirthDateField.parse('01/13/1960'), isNull);
    expect(BirthDateField.parse('01/01/0000'), isNull);
    expect(BirthDateField.parse(''), isNull);
    expect(BirthDateField.format(DateTime(1960, 2, 29)), '29/02/1960');
  });

  testWidgets(
      'date field validates invalid and future dates while allowing unknown dates',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
      key: key,
      child: BirthDateField(controller: controller),
    ))));
    expect(key.currentState!.validate(), isTrue);
    await tester.enterText(find.byType(TextFormField), '31/04/1960');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '01/01/2999');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '29/02/1960');
    expect(key.currentState!.validate(), isTrue);
  });
}
