import 'dart:async';

import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_realtime_port.dart';

export 'package:caregiver_app/features/booking_chat/data/booking_chat_realtime_port.dart';

/// Owns only Booking Chat subscriptions; the app service owns the shared hub.
class BookingChatRealtime implements BookingChatRealtimePort {
  BookingChatRealtime(this._hub) {
    _chatSubscription = _hub.bookingChatStream.listen((bookingId) {
      if (!_disposed && bookingId == _bookingId) _changes.add(null);
    });
    _reconnectSubscription = _hub.onReconnected.listen((_) {
      if (!_disposed && _bookingId != null) _changes.add(null);
    });
  }

  final CareSignalRService _hub;
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<String> _chatSubscription;
  late final StreamSubscription<void> _reconnectSubscription;
  String? _bookingId;
  bool _disposed = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> connect(String bookingId) async {
    if (_disposed || _bookingId == bookingId) return;
    final previousBookingId = _bookingId;
    _bookingId = bookingId;
    if (previousBookingId != null) {
      await _hub.leaveBooking(previousBookingId);
    }
    if (_disposed || _bookingId != bookingId) return;
    await _hub.joinBooking(bookingId);
    if (_disposed || _bookingId != bookingId) {
      await _hub.leaveBooking(bookingId);
    }
  }

  @override
  Future<void> disconnect() async {
    final bookingId = _bookingId;
    _bookingId = null;
    if (bookingId != null) await _hub.leaveBooking(bookingId);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final bookingId = _bookingId;
    _bookingId = null;
    if (bookingId != null) unawaited(_hub.leaveBooking(bookingId));
    unawaited(_chatSubscription.cancel());
    unawaited(_reconnectSubscription.cancel());
    unawaited(_changes.close());
  }
}
