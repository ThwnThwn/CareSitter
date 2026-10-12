class BookingErrorCodes {
  const BookingErrorCodes._();
  static const caregiverConflicts = {
    'booking.caregiver.schedule_conflict',
    'booking.caregiver.new_schedule_conflict',
  };
  static const selfExists = 'beneficiary.self_exists';
}
