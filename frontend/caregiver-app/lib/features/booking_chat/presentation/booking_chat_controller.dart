import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import '../data/booking_chat_realtime.dart';
import '../data/booking_chat_repository.dart';
import 'package:caresitter_booking_chat/caresitter_booking_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:caresitter_booking_chat/caresitter_booking_chat.dart'
    show BookingChatController, BookingChatState;

final bookingChatControllerProvider = StateNotifierProvider.autoDispose
    .family<BookingChatController, BookingChatState, String>((ref, bookingId) {
  ref.watch(authStateProvider.select((value) => (
        value.valueOrNull?.userId,
        value.valueOrNull?.isAuthenticated == true,
      )));
  return BookingChatController(
    bookingId: bookingId,
    repository: ref.read(bookingChatRepositoryProvider),
    realtime: BookingChatRealtime(ref.read(careSignalRProvider)),
  );
});
