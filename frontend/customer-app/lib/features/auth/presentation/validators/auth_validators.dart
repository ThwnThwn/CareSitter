class AuthValidators {
  const AuthValidators._();

  static final RegExp _emailPattern = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');

  static String? loginEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
    if (!_emailPattern.hasMatch(value.trim())) return 'Email không hợp lệ';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }
}
