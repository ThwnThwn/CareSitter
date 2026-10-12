class RecoveryEmailState {
  const RecoveryEmailState(
      {this.currentEmail,
      this.verified = false,
      this.hasPassword = false,
      this.loading = true,
      this.busy = false,
      this.challengeId,
      this.resendAt,
      this.expiresAt,
      this.now,
      this.error,
      this.message});
  final String? currentEmail, challengeId, error, message;
  final bool verified, hasPassword, loading, busy;
  final DateTime? resendAt, expiresAt, now;
  int get remaining => resendAt == null
      ? 0
      : (resendAt!.difference(now ?? DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 3600);
  bool get expired =>
      expiresAt != null && !(now ?? DateTime.now()).isBefore(expiresAt!);
  RecoveryEmailState copy(
          {String? currentEmail,
          bool? verified,
          bool? hasPassword,
          bool? loading,
          bool? busy,
          String? challengeId,
          DateTime? resendAt,
          DateTime? expiresAt,
          DateTime? now,
          String? error,
          String? message,
          bool clearChallenge = false}) =>
      RecoveryEmailState(
          currentEmail: currentEmail ?? this.currentEmail,
          verified: verified ?? this.verified,
          hasPassword: hasPassword ?? this.hasPassword,
          loading: loading ?? this.loading,
          busy: busy ?? this.busy,
          challengeId: clearChallenge ? null : challengeId ?? this.challengeId,
          resendAt: clearChallenge ? null : resendAt ?? this.resendAt,
          expiresAt: clearChallenge ? null : expiresAt ?? this.expiresAt,
          now: now ?? this.now,
          error: error,
          message: message);
}
