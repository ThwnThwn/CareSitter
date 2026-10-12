import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:flutter/material.dart';

class BirthDateField extends StatelessWidget {
  final TextEditingController controller;

  const BirthDateField({super.key, required this.controller});

  static DateTime? parse(String text) {
    final parts = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text.trim());
    if (parts == null) return null;
    final day = int.parse(parts[1]!);
    final month = int.parse(parts[2]!);
    final year = int.parse(parts[3]!);
    if (year < 1) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String format(DateTime? date) =>
      date == null ? '' : formatDate(date, padded: true);

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Ngày sinh',
          hintText: 'DD/MM/YYYY',
          helperText: 'Có thể để trống nếu chưa rõ ngày sinh.',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final date = parse(value);
          if (date == null) return 'Nhập ngày hợp lệ theo DD/MM/YYYY';
          final now = DateTime.now();
          if (date.isAfter(DateTime(now.year, now.month, now.day))) {
            return 'Ngày sinh không được ở tương lai';
          }
          return null;
        },
      );
}
