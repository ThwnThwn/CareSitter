class LoginInputRules {
  static String? identifier(String? value, {required bool usePassword}) {
    if (value == null || value.trim().isEmpty) {
      return usePassword
          ? 'Vui lòng nhập email hoặc số điện thoại'
          : 'Vui lòng nhập email';
    }
    if (!usePassword &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    return value.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null;
  }
}
