import 'package:caresitter_customer/core/utils/phone_formatter.dart';

String? beneficiaryContactsError(List<String> phones) {
  if (phones.length < 2) return '⚠️ Cần ít nhất 2 liên hệ khẩn cấp';
  final normalized =
      phones.map(normalizePhone).where((phone) => phone.isNotEmpty).toList();
  if (normalized.toSet().length != normalized.length) {
    return 'Các liên hệ khẩn cấp không được trùng số điện thoại.';
  }
  return null;
}
