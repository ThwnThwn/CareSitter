import 'dart:convert';

class RecoveryInputRules {
  static String? email(String? value) => value != null &&
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? null
      : 'Vui lòng nhập email hợp lệ.';

  static String? currentPassword(String? value) =>
      value == null || value.isEmpty
          ? 'Nhập mật khẩu hiện tại để đổi email.'
          : null;

  static String? code(String? value) =>
      value?.length == 6 ? null : 'Nhập đủ 6 chữ số.';
  static String? password(String? value) {
    if (value == null ||
        value.length < 8 ||
        value.toLowerCase() == value ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Cần ít nhất 8 ký tự, một chữ hoa và một chữ số.';
    }
    if (utf8.encode(value).length > 72) {
      return 'Mật khẩu quá dài (tối đa 72 byte).';
    }
    return null;
  }

  static String? confirmation(String? value, String password) =>
      value == password ? null : 'Mật khẩu xác nhận chưa khớp.';
}
