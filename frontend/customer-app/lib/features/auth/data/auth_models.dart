// ── Auth Models: Request/Response DTOs ──────────────────────────────────────
// Khớp đúng với backend: RegisterCommand, LoginWithPasswordCommand, LoginCommand, SendOtpCommand

/// Đăng nhập bằng Email + Password → POST /auth/login/password
class LoginRequest {
  final String email;
  final String password;
  final String requiredRole;

  const LoginRequest({
    required this.email,
    required this.password,
    this.requiredRole = 'CUSTOMER',
  });

  Map<String, dynamic> toJson() => {
        'Email': email,
        'Password': password,
        'RequiredRole': requiredRole,
        'email': email,
        'password': password,
        'requiredRole': requiredRole,
      };
}

/// Đăng ký tài khoản mới → POST /auth/register
/// Backend nhận: Email, FullName, Roles[], Password?, ConfirmPassword?
class RegisterRequest {
  final String fullName;
  final String email;
  final String password;
  final String confirmPassword;
  final String? phone;
  final List<String> roles;

  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.phone,
    this.roles = const ['CUSTOMER'],
  });

  Map<String, dynamic> toJson() => {
        'Email': email,
        'FullName': fullName,
        'Password': password,
        'ConfirmPassword': confirmPassword,
        if (phone != null && phone!.trim().isNotEmpty) 'Phone': phone!.trim(),
        'Roles': roles,
        'email': email,
        'fullName': fullName,
        'password': password,
        'confirmPassword': confirmPassword,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        'roles': roles,
      };
}

/// Gửi OTP tới email → POST /auth/send-otp
class OtpSendRequest {
  final String email;
  const OtpSendRequest({required this.email});
  Map<String, dynamic> toJson() => {
        'Email': email,
        'email': email,
      };
}

/// Xác thực OTP + đăng nhập → POST /auth/login
class OtpVerifyRequest {
  final String email;
  final String otp;
  final String requiredRole;
  const OtpVerifyRequest({
    required this.email,
    required this.otp,
    this.requiredRole = 'CUSTOMER',
  });
  Map<String, dynamic> toJson() => {
        'Email': email,
        'Otp': otp,
        'RequiredRole': requiredRole,
        'email': email,
        'otp': otp,
        'requiredRole': requiredRole,
      };
}

/// Response khi login / register thành công.
/// Hỗ trợ parse cả camelCase lẫn PascalCase, hoặc bọc trong data envelope.
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final List<String> roles;
  final String? displayName;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.roles,
    this.displayName,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Hỗ trợ cả hai dạng: trực tiếp hoặc bọc trong "data"
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    // Access Token (JWT)
    final accessToken = data['accessToken'] as String? ??
        data['AccessToken'] as String? ??
        data['jwt'] as String? ??
        data['token'] as String? ??
        data['Token'] as String? ??
        '';

    // Refresh Token
    final refreshToken = data['refreshToken'] as String? ??
        data['RefreshToken'] as String? ??
        data['refresh_token'] as String? ??
        '';

    // User ID (Guid hoặc String)
    final userId = data['userId'] as String? ??
        data['UserId'] as String? ??
        data['id'] as String? ??
        data['Id'] as String? ??
        data['user_id'] as String? ??
        '';

    // Roles (List<String>)
    final rawRoles = data['roles'] ?? data['Roles'];
    final roles = rawRoles is List
        ? rawRoles.map((e) => e.toString()).toList()
        : <String>[];

    // Display Name / Full Name
    final displayName = data['displayName'] as String? ??
        data['DisplayName'] as String? ??
        data['fullName'] as String? ??
        data['FullName'] as String? ??
        data['name'] as String? ??
        data['Name'] as String?;

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      roles: roles,
      displayName: displayName,
    );
  }
}
