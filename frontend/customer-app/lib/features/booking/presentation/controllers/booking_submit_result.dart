sealed class BookingSubmitResult {
  const BookingSubmitResult();
}

final class BookingSubmitted extends BookingSubmitResult {
  const BookingSubmitted(this.id, this.message);
  final String id, message;
}

final class BookingSubmitMessage extends BookingSubmitResult {
  const BookingSubmitMessage(this.message, {this.caregiverConflict = false});
  final String message;
  final bool caregiverConflict;
}

final class BookingSubmitIgnored extends BookingSubmitResult {
  const BookingSubmitIgnored();
}
