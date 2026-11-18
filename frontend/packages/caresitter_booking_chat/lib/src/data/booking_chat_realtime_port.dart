abstract interface class BookingChatRealtimePort {
  Stream<void> get changes;
  Future<void> connect(String bookingId);
  Future<void> disconnect();
  void dispose();
}
