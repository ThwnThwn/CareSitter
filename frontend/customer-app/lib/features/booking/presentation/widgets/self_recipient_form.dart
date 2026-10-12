import 'package:caresitter_customer/features/booking/presentation/widgets/self_recipient_form_name_birth_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/self_recipient_controller.dart';

/// Draft chỉ tồn tại trong phiên wizard; các trường gửi thay đổi lên controller,
/// không gọi API ghi dữ liệu tại đây.
class SelfRecipientForm extends ConsumerStatefulWidget {
  final BeneficiaryModel initial;
  final ValueChanged<BeneficiaryModel> onChanged;
  final ValueChanged<bool> onDateValidityChanged;
  const SelfRecipientForm(
      {super.key,
      required this.initial,
      required this.onChanged,
      required this.onDateValidityChanged});

  @override
  ConsumerState<SelfRecipientForm> createState() => _SelfRecipientFormState();
}

class _SelfRecipientFormState extends ConsumerState<SelfRecipientForm> {
  late final TextEditingController _name;
  late final TextEditingController _birth;
  late final TextEditingController _note;
  late final TextEditingController _instructions;
  late final List<TextEditingController> _contactNames;
  late final List<TextEditingController> _contactPhones;
  late final List<TextEditingController> _contactRelations;
  String? _gender;
  String? _careLevel;

  @override
  void initState() {
    super.initState();
    final profile = widget.initial;
    _name = TextEditingController(text: profile.name);
    _birth =
        TextEditingController(text: BirthDateField.format(profile.dateOfBirth));
    _note = TextEditingController(text: profile.condition);
    _instructions = TextEditingController(text: profile.notes);
    _gender = const ['MALE', 'FEMALE', 'OTHER', 'UNSPECIFIED']
            .contains(profile.gender)
        ? profile.gender
        : null;
    _careLevel = const ['Nhẹ', 'Trung bình', 'Nặng'].contains(profile.careLevel)
        ? profile.careLevel
        : null;
    final contacts = [...profile.emergencyContacts];
    while (contacts.length < 2) {
      contacts
          .add(const EmergencyContact(name: '', phone: '', relationship: ''));
    }
    _contactNames =
        contacts.map((c) => TextEditingController(text: c.name)).toList();
    _contactPhones =
        contacts.map((c) => TextEditingController(text: c.phone)).toList();
    _contactRelations = contacts
        .map((c) => TextEditingController(text: c.relationship))
        .toList();
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
  }

  List<TextEditingController> get _controllers => [
        _name,
        _birth,
        _note,
        _instructions,
        ..._contactNames,
        ..._contactPhones,
        ..._contactRelations
      ];

  void _changed() {
    final dob = BirthDateField.parse(_birth.text);
    final now = DateTime.now();
    final valid = _birth.text.trim().isEmpty ||
        (dob != null && !dob.isAfter(DateTime(now.year, now.month, now.day)));
    widget.onDateValidityChanged(valid);
    widget.onChanged(widget.initial.copyWith(
        name: _name.text.trim(),
        dateOfBirth: dob,
        gender: _gender,
        careLevel: _careLevel ?? '',
        condition: _note.text.trim(),
        notes: _instructions.text.trim(),
        emergencyContacts: [
          for (var i = 0; i < _contactNames.length; i++)
            EmergencyContact(
                name: _contactNames[i].text.trim(),
                phone: _contactPhones[i].text.trim(),
                relationship: _contactRelations[i].text.trim()),
        ]));
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SelfRecipientFormNameBirthFields(
            name: _name,
            birth: _birth,
            gender: _gender,
            careLevel: _careLevel,
            note: _note,
            instructions: _instructions,
            contactNames: _contactNames,
            contactPhones: _contactPhones,
            contactRelations: _contactRelations,
            ref: ref,
            mounted: mounted,
            callbackAction4: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập họ tên'
                : null,
            callbackAction5: (value) {
              _gender = value;
              _changed();
            },
            callbackAction6: (value) {
              _careLevel = value;
              _changed();
            },
            callbackAction7: (c) => c.fullName,
            callbackAction8: (c) => c.phoneNumber,
            callbackAction9: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập tên liên hệ'
                : null,
            callbackAction10: (value) {
              final phone = SelfRecipient.normalizePhone(value ?? '');
              if (!RegExp(r'^0[3-9][0-9]{8}$').hasMatch(phone)) {
                return 'Số điện thoại không hợp lệ';
              }
              if (_contactPhones
                      .where(
                          (c) => SelfRecipient.normalizePhone(c.text) == phone)
                      .length >
                  1) {
                return 'Các liên hệ cần khác số điện thoại';
              }
              return null;
            }),
      );
}
