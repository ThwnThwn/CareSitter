import 'package:caresitter_customer/core/utils/phone_formatter.dart';

String? beneficiaryContactNameError(String? value) =>
    (value?.trim().isEmpty ?? true) ? 'Vui lòng nhập tên liên hệ' : null;

String? beneficiaryContactPhoneError(String? value) {
  if (value?.trim().isEmpty ?? true) return 'Vui lòng nhập số điện thoại';
  return RegExp(r'^0[3-9]\d{8}$').hasMatch(value!.trim())
      ? null
      : 'Số điện thoại không hợp lệ';
}

String? beneficiaryContactsError(List<String> phones) {
  if (phones.length < 2) return '⚠️ Cần ít nhất 2 liên hệ khẩn cấp';
  final normalized =
      phones.map(normalizePhone).where((phone) => phone.isNotEmpty).toList();
  if (normalized.toSet().length != normalized.length) {
    return 'Các liên hệ khẩn cấp không được trùng số điện thoại.';
  }
  return null;
}
