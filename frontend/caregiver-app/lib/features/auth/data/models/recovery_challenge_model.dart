class RecoveryChallenge {
  const RecoveryChallenge(
      this.id, this.expiresIn, this.resendAfter, this.message);
  final String id;
  final int expiresIn;
  final int resendAfter;
  final String message;
  factory RecoveryChallenge.fromJson(Map<String, dynamic> json) =>
      RecoveryChallenge(
          json['challengeId'] as String,
          (json['expiresIn'] as num).toInt(),
          (json['resendAfter'] as num).toInt(),
          json['message'] as String);
}
