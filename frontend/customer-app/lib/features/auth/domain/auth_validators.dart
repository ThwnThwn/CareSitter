class AuthValidators {
  const AuthValidators._();

  static final RegExp _emailPattern = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
  static final RegExp _phonePattern = RegExp(r'^(\+84|0)[0-9]{9}$');
  static final RegExp _phoneSeparators = RegExp(r'[\s().-]');

  static String? loginEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập email hoặc số điện thoại';
    }
    final trimmed = value.trim();
    final compactPhone = trimmed.replaceAll(_phoneSeparators, '');
    if (_emailPattern.hasMatch(trimmed) ||
        _phonePattern.hasMatch(compactPhone)) {
      return null;
    }
    return 'Email hoặc số điện thoại không hợp lệ';
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }
}
