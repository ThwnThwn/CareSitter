class PasswordRecoveryState {
  const PasswordRecoveryState({
    this.step = 0,
    this.busy = false,
    this.error,
    this.challengeId,
    this.resendAt,
    this.codeExpiresAt,
    this.grantExpiresAt,
    this.now,
    this.message = '',
    this.expiresIn = 0,
  });
  final int step;
  final bool busy;
  final String? error;
  final String? challengeId;
  final DateTime? resendAt, codeExpiresAt, grantExpiresAt, now;
  final String message;
  final int expiresIn;
  int get remaining => resendAt == null
      ? 0
      : (resendAt!.difference(now ?? DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 3600);
  bool get expired =>
      codeExpiresAt != null &&
      !(now ?? DateTime.now()).isBefore(codeExpiresAt!);
  PasswordRecoveryState copy(
          {int? step,
          bool? busy,
          String? error,
          String? challengeId,
          DateTime? resendAt,
          DateTime? codeExpiresAt,
          DateTime? grantExpiresAt,
          DateTime? now}) =>
      PasswordRecoveryState(
          step: step ?? this.step,
          busy: busy ?? this.busy,
          error: error,
          challengeId: challengeId ?? this.challengeId,
          resendAt: resendAt ?? this.resendAt,
          codeExpiresAt: codeExpiresAt ?? this.codeExpiresAt,
          grantExpiresAt: grantExpiresAt ?? this.grantExpiresAt,
          now: now ?? this.now,
          message: message,
          expiresIn: expiresIn);
}
