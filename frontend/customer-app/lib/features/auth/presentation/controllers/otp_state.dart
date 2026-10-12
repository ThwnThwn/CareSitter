class OtpState {
  const OtpState(
      {this.countdown = 60,
      this.verifying = false,
      this.resending = false,
      this.error});
  final int countdown;
  final bool verifying, resending;
  final String? error;
}
