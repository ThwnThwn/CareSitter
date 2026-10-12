String? registrationName(String? v) {
  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập họ và tên';
  if (v.trim().length < 2) return 'Họ tên quá ngắn';
  return null;
}

String? registrationEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
  final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
  if (!emailRegex.hasMatch(v.trim())) return 'Email không hợp lệ';
  return null;
}

String? registrationPhone(String? v) {
  if (v == null || v.isEmpty) return 'Vui lòng nhập số điện thoại';
  if (!RegExp(r'^(0[3-9]\d{8})$').hasMatch(v)) {
    return 'Số điện thoại không hợp lệ';
  }
  return null;
}

String? registrationPassword(String? v) {
  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
  if (v.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
  if (!RegExp(r'[A-Z]').hasMatch(v)) {
    return 'Mật khẩu phải có ít nhất 1 chữ hoa';
  }
  if (!RegExp(r'[0-9]').hasMatch(v)) {
    return 'Mật khẩu phải có ít nhất 1 chữ số';
  }
  return null;
}

String? registrationConfirmation(String? v, String password) {
  if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
  if (v != password) return 'Mật khẩu không khớp';
  return null;
}
