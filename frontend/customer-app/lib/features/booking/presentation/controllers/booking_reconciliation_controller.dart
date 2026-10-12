import 'package:caresitter_customer/features/booking/data/models/booking_list_response.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/booking_draft.dart';
import 'booking_submit_result.dart';

/// Đối soát chỉ bằng GET; chưa có idempotency bền thì không lặp POST booking.
class BookingReconciliationController {
  BookingReconciliationController(this.getBookings);
  final Future<BookingListResponse> Function(
      {required int page, required int pageSize}) getBookings;
  static const maximumPages = 10, pageSize = 50;
  Future<BookingSubmitResult> reconcile(BookingDraft draft,
      {required bool Function() current}) async {
    final matches = <BookingModel>[];
    var exhaustive = false;
    try {
      for (var page = 1; page <= maximumPages; page++) {
        if (!current()) return const BookingSubmitIgnored();
        final result = await getBookings(page: page, pageSize: pageSize);
        if (!current()) return const BookingSubmitIgnored();
        matches.addAll(result.items.where((booking) =>
            booking.beneficiaryId == draft.beneficiaryId &&
            booking.serviceTypeId == draft.serviceTypeId &&
            booking.addressId == draft.addressId &&
            booking.scheduledStart.isAtSameMomentAs(draft.scheduledStart) &&
            booking.scheduledEnd.isAtSameMomentAs(draft.scheduledEnd)));
        if (result.items.length < pageSize ||
            result.page * result.pageSize >= result.total) {
          exhaustive = true;
          break;
        }
      }
      return exhaustive && matches.length == 1
          ? BookingSubmitted(matches.single.id, 'Đã tìm thấy lịch đã gửi.')
          : const BookingSubmitMessage(
              'Chưa xác minh được kết quả. Vui lòng kiểm tra danh sách lịch hoặc liên hệ hỗ trợ.');
    } catch (_) {
      return current()
          ? const BookingSubmitMessage('Chưa tải được lịch. Vui lòng kiểm tra lại.')
          : const BookingSubmitIgnored();
    }
  }
}
