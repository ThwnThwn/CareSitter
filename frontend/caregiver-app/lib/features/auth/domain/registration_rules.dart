String? registrationName(String? value) =>
    (value?.trim().length ?? 0) < 2 ? 'Vui lòng nhập đầy đủ họ tên' : null;

String? registrationEmail(String? value) =>
    RegExp(r'^[\w.+-]+@[\w-]+(?:\.[\w-]+)+$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Email không hợp lệ';

String? registrationPhone(String? value) =>
    RegExp(r'^0[3-9]\d{8}$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Số điện thoại Việt Nam gồm 10 chữ số';

String? registrationPassword(String? value) {
  final text = value ?? '';
  if (text.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
  if (!RegExp(r'[A-Z]').hasMatch(text)) return 'Cần ít nhất một chữ hoa';
  if (!RegExp(r'\d').hasMatch(text)) return 'Cần ít nhất một chữ số';
  return null;
}

String? registrationConfirmation(String? value, String password) =>
    value != password ? 'Mật khẩu xác nhận không khớp' : null;
