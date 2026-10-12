import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_birth_date_field.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/family_contact_picker.dart';
import '../controllers/self_recipient_controller.dart';

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
    _birth = TextEditingController(
        text: BeneficiaryBirthDateField.format(profile.dateOfBirth));
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
    final dob = BeneficiaryBirthDateField.parse(_birth.text);
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Kiểm tra thông tin của bạn. Hồ sơ chăm sóc sẽ được lưu khi xác nhận đặt lịch.'),
          const SizedBox(height: 16),
          TextFormField(
              controller: _name,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Họ tên của tôi *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập họ tên'
                  : null),
          const SizedBox(height: 12),
          BeneficiaryBirthDateField(controller: _birth),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              initialValue: _gender,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giới tính'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Chưa cập nhật')),
                DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                DropdownMenuItem(
                    value: 'UNSPECIFIED', child: Text('Không muốn cung cấp'))
              ],
              onChanged: (value) {
                _gender = value;
                _changed();
              }),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              initialValue: _careLevel,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Mức hỗ trợ cần thiết'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Chưa cập nhật')),
                DropdownMenuItem(value: 'Nhẹ', child: Text('Nhẹ')),
                DropdownMenuItem(
                    value: 'Trung bình', child: Text('Trung bình')),
                DropdownMenuItem(value: 'Nặng', child: Text('Nặng'))
              ],
              onChanged: (value) {
                _careLevel = value;
                _changed();
              }),
          const SizedBox(height: 16),
          TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Ghi chú về tình trạng của tôi')),
          const SizedBox(height: 16),
          TextFormField(
              controller: _instructions,
              minLines: 2,
              maxLines: 4,
              decoration:
                  const InputDecoration(labelText: 'Lưu ý khi chăm sóc')),
          const SizedBox(height: 24),
          Text('Liên hệ khẩn cấp',
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
              'Cần hai người có số điện thoại khác nhau để liên hệ khi cần.'),
          for (var i = 0; i < _contactNames.length; i++) ...[
            const SizedBox(height: 16),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Liên hệ ${i + 1}'),
                  TextButton.icon(
                      icon: const Icon(Icons.contacts_outlined),
                      label: const Text('Chọn từ danh bạ'),
                      onPressed: () async {
                        final contact = await pickFamilyContact(context, ref);
                        if (!mounted || contact == null) return;
                        _contactNames[i].text = contact.fullName;
                        _contactPhones[i].text = contact.phoneNumber;
                      })
                ]),
            TextFormField(
                controller: _contactNames[i],
                decoration:
                    InputDecoration(labelText: 'Họ tên liên hệ ${i + 1} *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tên liên hệ'
                    : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _contactPhones[i],
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: 'Số điện thoại liên hệ ${i + 1} *'),
                validator: (value) {
                  final phone = SelfRecipient.normalizePhone(value ?? '');
                  if (!RegExp(r'^0[3-9][0-9]{8}$').hasMatch(phone)) {
                    return 'Số điện thoại không hợp lệ';
                  }
                  if (_contactPhones
                          .where((c) =>
                              SelfRecipient.normalizePhone(c.text) == phone)
                          .length >
                      1) {
                    return 'Các liên hệ cần khác số điện thoại';
                  }
                  return null;
                }),
            const SizedBox(height: 12),
            TextFormField(
                controller: _contactRelations[i],
                decoration:
                    InputDecoration(labelText: 'Quan hệ của liên hệ ${i + 1}')),
          ],
        ]),
      );
}
