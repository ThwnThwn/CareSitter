import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import '../../data/models/beneficiary_model.dart';
import 'beneficiary_contact_entry.dart';
import '../controllers/beneficiary_form_state.dart';

class BeneficiaryFormFields {
  final name = TextEditingController();
  final birthDate = TextEditingController();
  final condition = TextEditingController();
  final notes = TextEditingController();
  final contacts = [BeneficiaryContactEntry(), BeneficiaryContactEntry()];
  String fingerprint(BeneficiaryFormState draft) => [
        name.text,
        birthDate.text,
        draft.addressId ?? '',
        draft.gender,
        draft.relation,
        draft.careLevel,
        condition.text,
        ...draft.conditions,
        notes.text,
        draft.avatarPath ?? '',
        for (final entry in contacts) ...[
          entry.nameCtrl.text,
          entry.phoneCtrl.text,
          entry.relationship
        ],
      ].toString();
  void load(BeneficiaryModel profile) {
    name.text = profile.name;
    birthDate.text = BirthDateField.format(profile.dateOfBirth);
    condition.clear();
    notes.text = profile.notes;
    for (final contact in contacts) {
      contact.dispose();
    }
    contacts.clear();
    for (final contact in profile.emergencyContacts) {
      final entry = BeneficiaryContactEntry();
      entry.nameCtrl.text = contact.name;
      entry.phoneCtrl.text = contact.phone;
      entry.relationship = contact.relationship;
      contacts.add(entry);
    }
    while (contacts.length < 2) {
      contacts.add(BeneficiaryContactEntry());
    }
  }

  void dispose() {
    name.dispose();
    birthDate.dispose();
    condition.dispose();
    notes.dispose();
    for (final contact in contacts) {
      contact.dispose();
    }
  }
}
