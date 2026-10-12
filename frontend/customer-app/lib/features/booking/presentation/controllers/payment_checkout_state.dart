class PaymentCheckoutState {
  const PaymentCheckoutState({this.selected, this.busy = false, this.error});
  final String? selected, error;
  final bool busy;
}
