sealed class ShiftActionResult {
  const ShiftActionResult();
}

final class ShiftActionSuccess extends ShiftActionResult {
  const ShiftActionSuccess();
}

final class ShiftActionIgnored extends ShiftActionResult {
  const ShiftActionIgnored();
}

final class ShiftActionFailure extends ShiftActionResult {
  const ShiftActionFailure(this.message);
  final String message;
}
