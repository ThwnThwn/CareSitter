class AuthUserModel {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String displayName;
  final List<String> roles;

  const AuthUserModel({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.displayName,
    required this.roles,
  });

  factory AuthUserModel.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDisplayName,
  }) {
    return AuthUserModel(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? fallbackDisplayName,
      roles: _parseRoles(json['roles'] ?? json['Roles']),
    );
  }

  bool hasRole(String role) => roles.contains(role.trim().toUpperCase());

  static List<String> _parseRoles(Object? rawRoles) {
    if (rawRoles is! List) return const [];
    return rawRoles
        .map((role) => role.toString().trim().toUpperCase())
        .where((role) => role.isNotEmpty)
        .toList(growable: false);
  }
}
