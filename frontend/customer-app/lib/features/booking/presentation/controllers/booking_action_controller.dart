import 'package:caresitter_customer/core/error/app_exception.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/models/booking_model.dart';
import 'booking_created_exception.dart';
import 'booking_outcome_unknown.dart';
import 'booking_state_controller.dart';

class BookingActionController {
  BookingActionController(this.repository, this.store);
  final BookingRepository repository;
  final BookingStateController store;
  void _requireSession() {
    if (!store.active || store.userId == null) {
      throw StateError('Phiên đặt lịch đã thay đổi.');
    }
  }

  Future<BookingModel> create(BookingDraft draft) async {
    _requireSession();
    BookingModel created;
    try {
      created = await repository.createBooking(draft);
      if (created.id.isEmpty) throw const BookingOutcomeUnknown();
    } on AppApiException catch (e) {
      if (e.outcomeMayBeUnknown) throw const BookingOutcomeUnknown();
      rethrow;
    } catch (_) {
      throw const BookingOutcomeUnknown();
    }
    _requireSession();
    store.apply(created, insert: true);
    if (!draft.isSystemMatched && draft.caregiverId != null) {
      try {
        created = await repository.selectCaregiver(created.id,
            caregiverId: draft.caregiverId!);
      } catch (_) {
        _requireSession();
        throw BookingCreatedException(created);
      }
    }
    _requireSession();
    store.apply(created);
    return created;
  }

  Future<void> enRoute(String id) =>
      _update(() => repository.startEnRoute(id), silent: true);
  Future<void> checkIn(String id,
          {required double latitude, required double longitude}) =>
      _update(
          () =>
              repository.checkIn(id, latitude: latitude, longitude: longitude),
          silent: true);
  Future<void> checkout(String id) =>
      _update(() => repository.requestCheckout(id), silent: true);
  Future<void> complete(String id) =>
      _update(() => repository.completeBooking(id));
  Future<void> cancel(String id, {String? reason}) =>
      _update(() => repository.cancelBooking(id, reason: reason));
  Future<void> _update(Future<BookingModel> Function() action,
      {bool silent = false}) async {
    if (!store.active) {
      if (!silent) throw StateError('Phiên đặt lịch đã thay đổi.');
      return;
    }
    try {
      final updated = await action();
      if (!store.active) {
        if (!silent) throw StateError('Phiên đặt lịch đã thay đổi.');
        return;
      }
      store.apply(updated);
    } catch (_) {
      if (!silent) rethrow;
    }
  }
}
