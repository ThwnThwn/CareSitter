import 'package:caresitter_customer/features/booking/presentation/widgets/self_recipient_form_i_contact_names_fields.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/family_contact_controller.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:caresitter_customer/core/widgets/family_contact_picker.dart';

class SelfRecipientFormNameBirthFields extends StatelessWidget {
  const SelfRecipientFormNameBirthFields(
      {super.key,
      required this.name,
      required this.birth,
      required this.gender,
      required this.careLevel,
      required this.note,
      required this.instructions,
      required this.contactNames,
      required this.contactPhones,
      required this.contactRelations,
      required this.ref,
      required this.mounted,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6,
      required this.callbackAction7,
      required this.callbackAction8,
      required this.callbackAction9,
      required this.callbackAction10});
  final TextEditingController name;
  final TextEditingController birth;
  final String? gender;
  final String? careLevel;
  final TextEditingController note;
  final TextEditingController instructions;
  final List<TextEditingController> contactNames;
  final List<TextEditingController> contactPhones;
  final List<TextEditingController> contactRelations;
  final WidgetRef ref;
  final bool mounted;
  final String? Function(String?) callbackAction4;
  final void Function(String?) callbackAction5;
  final void Function(String?) callbackAction6;
  final String Function(FamilyContactModel) callbackAction7;
  final String Function(FamilyContactModel) callbackAction8;
  final String? Function(String?) callbackAction9;
  final String? Function(String?) callbackAction10;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Kiểm tra thông tin của bạn. Hồ sơ chăm sóc sẽ được lưu khi xác nhận đặt lịch.'),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
            controller: name,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Họ tên của tôi *'),
            validator: callbackAction4),
        const SizedBox(height: AppSpacing.compact),
        BirthDateField(controller: birth),
        const SizedBox(height: AppSpacing.md),
        AppDropdownField<String>(
            initialValue: gender,
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
            onChanged: callbackAction5),
        const SizedBox(height: AppSpacing.md),
        AppDropdownField<String>(
            initialValue: careLevel,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Mức hỗ trợ cần thiết'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Chưa cập nhật')),
              DropdownMenuItem(value: 'Nhẹ', child: Text('Nhẹ')),
              DropdownMenuItem(value: 'Trung bình', child: Text('Trung bình')),
              DropdownMenuItem(value: 'Nặng', child: Text('Nặng'))
            ],
            onChanged: callbackAction6),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Ghi chú về tình trạng của tôi')),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
            controller: instructions,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Lưu ý khi chăm sóc')),
        const SizedBox(height: AppSpacing.lg),
        Text('Liên hệ khẩn cấp',
            style: Theme.of(context).textTheme.titleMedium),
        const Text(
            'Cần hai người có số điện thoại khác nhau để liên hệ khi cần.'),
        for (var i = 0; i < contactNames.length; i++)
          SelfRecipientFormIContactNamesFields(
              i: i,
              contactNames: contactNames,
              contactPhones: contactPhones,
              contactRelations: contactRelations,
              callbackAction1: () async {
                final contact = await pickFamilyContact(context, ref,
                    provider: familyContactsProvider,
                    name: callbackAction7,
                    phone: callbackAction8);
                if (!mounted || contact == null) return;
                contactNames[i].text = contact.fullName;
                contactPhones[i].text = contact.phoneNumber;
              },
              callbackAction2: callbackAction9,
              callbackAction3: callbackAction10),
      ]);
}
