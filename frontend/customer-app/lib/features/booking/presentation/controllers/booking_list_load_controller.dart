import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BookingListLoadState { loading, ready, failed }

final bookingListLoadProvider =
    NotifierProvider<BookingListLoadController, BookingListLoadState>(
        BookingListLoadController.new);

class BookingListLoadController extends Notifier<BookingListLoadState> {
  @override
  BookingListLoadState build() {
    final session = ref.watch(authStateProvider.select((auth) =>
        (auth.valueOrNull?.userId, auth.valueOrNull?.isAuthenticated)));
    return session.$1 != null && session.$2 == true
        ? BookingListLoadState.loading
        : BookingListLoadState.ready;
  }

  void update(BookingListLoadState next) => state = next;
}
