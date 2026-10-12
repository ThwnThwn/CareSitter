class RecoveryEmailModel {
  const RecoveryEmailModel(
      {required this.email,
      this.verified = false,
      this.hasPassword = false,
      this.sessionsRevoked = false});
  final String email;
  final bool verified, hasPassword, sessionsRevoked;
  factory RecoveryEmailModel.fromJson(Map<String, dynamic> json) =>
      RecoveryEmailModel(
          email: json['email'] as String,
          verified: json['emailVerifiedAt'] != null,
          hasPassword: json['hasPassword'] == true,
          sessionsRevoked: json['sessionsRevoked'] == true);
}
