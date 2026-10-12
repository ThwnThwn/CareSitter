import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SelfRecipientFormIContactNamesFields extends StatelessWidget {
  const SelfRecipientFormIContactNamesFields(
      {super.key,
      required this.i,
      required this.contactNames,
      required this.contactPhones,
      required this.contactRelations,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3});
  final int i;
  final List<TextEditingController> contactNames;
  final List<TextEditingController> contactPhones;
  final List<TextEditingController> contactRelations;
  final Future<void> Function() callbackAction1;
  final String? Function(String?) callbackAction2;
  final String? Function(String?) callbackAction3;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Liên hệ ${i + 1}'),
                  TextButton.icon(
                      icon: const Icon(Icons.contacts_outlined),
                      label: const Text('Chọn từ danh bạ'),
                      onPressed: callbackAction1)
                ]),
            TextFormField(
                controller: contactNames[i],
                decoration:
                    InputDecoration(labelText: 'Họ tên liên hệ ${i + 1} *'),
                validator: callbackAction2),
            const SizedBox(height: AppSpacing.compact),
            TextFormField(
                controller: contactPhones[i],
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: 'Số điện thoại liên hệ ${i + 1} *'),
                validator: callbackAction3),
            const SizedBox(height: AppSpacing.compact),
            TextFormField(
                controller: contactRelations[i],
                decoration:
                    InputDecoration(labelText: 'Quan hệ của liên hệ ${i + 1}')),
          ]);
}
