class RegistrationState {
  const RegistrationState({this.busy = false, this.agreed = false, this.error});
  final bool busy, agreed;
  final String? error;
}
