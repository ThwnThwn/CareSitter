class SettingsInputRules {
  static String? profileName(String? value) =>
      value == null || value.trim().length < 2
          ? 'Vui lòng nhập họ tên hợp lệ (ít nhất 2 ký tự)'
          : null;
  static String? email(String? value) =>
      value != null && value.isNotEmpty && !value.contains('@')
          ? 'Email không hợp lệ'
          : null;
  static String? currentPassword(String? value) =>
      value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu cũ' : null;
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu mới';
    return value.length < 8 ? 'Mật khẩu phải có ít nhất 8 ký tự' : null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
    return value != password ? 'Mật khẩu xác nhận không khớp' : null;
  }
}
