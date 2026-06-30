import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_data.dart';

class BookingDraft {
  final String beneficiaryId;
  final String beneficiaryName;
  final String caregiverId;
  final String caregiverName;
  final String caregiverAvatar;
  final String serviceId;
  final String serviceName;
  final String date;
  final String time;
  final String duration;
  final double totalPrice;
  final String address;
  final bool isSystemMatched;
  final bool isDemoBooking;
  final String paymentLabel;

  const BookingDraft({
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.caregiverId,
    required this.caregiverName,
    required this.caregiverAvatar,
    required this.serviceId,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.duration,
    required this.totalPrice,
    required this.address,
    required this.isSystemMatched,
    required this.isDemoBooking,
    required this.paymentLabel,
  });
}

final bookingStoreProvider =
    NotifierProvider<BookingStore, List<MockBooking>>(BookingStore.new);

class BookingStore extends Notifier<List<MockBooking>> {
  @override
  List<MockBooking> build() {
    return MockData.bookings
        .map((booking) => booking.tasks.isEmpty
            ? booking.copyWith(tasks: defaultTasksFor(booking.serviceName))
            : booking)
        .toList(growable: false);
  }

  MockBooking createBooking(BookingDraft draft) {
    final booking = MockBooking(
      id: 'bk${DateTime.now().millisecondsSinceEpoch}',
      beneficiaryId: draft.beneficiaryId,
      beneficiaryName: draft.beneficiaryName,
      caregiverId: draft.caregiverId,
      caregiverName: draft.caregiverName,
      caregiverAvatar: draft.caregiverAvatar,
      serviceId: draft.serviceId,
      serviceName: draft.serviceName,
      date: draft.date,
      time: draft.time,
      duration: draft.duration,
      status: 'pending',
      totalPrice: draft.totalPrice,
      address: draft.address,
      isSystemMatched: draft.isSystemMatched,
      isDemoBooking: draft.isDemoBooking,
      paymentLabel: draft.paymentLabel,
      consentAcceptedAt: DateTime.now(),
      tasks: defaultTasksFor(draft.serviceName),
    );
    state = [booking, ...state];
    return booking;
  }

  void caregiverAccept(String bookingId) {
    _transition(bookingId, from: const {'pending'}, to: 'confirmed');
  }

  void caregiverEnRoute(String bookingId) {
    _transition(bookingId, from: const {'confirmed'}, to: 'en_route');
  }

  void caregiverCheckIn(String bookingId) {
    _transition(bookingId, from: const {'confirmed', 'en_route'}, to: 'in_progress');
  }

  void caregiverRequestCheckout(String bookingId) {
    _replace(
      bookingId,
      (booking) {
        _ensureStatus(booking, const {'in_progress'});
        return booking.copyWith(
          status: 'checkout_requested',
          checkoutRequestedAt: DateTime.now(),
          tasks: booking.tasks
              .map((task) => task.copyWith(isCompleted: true))
              .toList(growable: false),
        );
      },
    );
  }

  void confirmCompleted(String bookingId) {
    _replace(
      bookingId,
      (booking) {
        _ensureStatus(booking, const {'checkout_requested'});
        return booking.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
          platformRevenue: booking.totalPrice * 0.15,
          caregiverEarning: booking.totalPrice * 0.85,
        );
      },
    );
  }

  void openDispute(String bookingId, String reason) {
    _replace(
      bookingId,
      (booking) {
        _ensureStatus(
          booking,
          const {'in_progress', 'checkout_requested', 'completed'},
        );
        return booking.copyWith(status: 'disputed', disputeReason: reason);
      },
    );
  }

  void markReviewed(String bookingId) {
    _replace(
      bookingId,
      (booking) {
        _ensureStatus(booking, const {'completed'});
        return booking.copyWith(isReviewed: true);
      },
    );
  }

  void cancel(String bookingId) {
    _transition(
      bookingId,
      from: const {'pending', 'confirmed'},
      to: 'cancelled',
    );
  }

  void toggleTask(String bookingId, int taskIndex) {
    _replace(
      bookingId,
      (booking) {
        _ensureStatus(booking, const {'in_progress'});
        if (taskIndex < 0 || taskIndex >= booking.tasks.length) return booking;
        final tasks = [...booking.tasks];
        tasks[taskIndex] = tasks[taskIndex].copyWith(
          isCompleted: !tasks[taskIndex].isCompleted,
        );
        return booking.copyWith(tasks: tasks);
      },
    );
  }

  void _transition(
    String bookingId, {
    required Set<String> from,
    required String to,
  }) {
    _replace(bookingId, (booking) {
      _ensureStatus(booking, from);
      return booking.copyWith(status: to);
    });
  }

  void _replace(
    String bookingId,
    MockBooking Function(MockBooking booking) update,
  ) {
    state = [
      for (final booking in state)
        if (booking.id == bookingId) update(booking) else booking,
    ];
  }

  void _ensureStatus(MockBooking booking, Set<String> allowed) {
    if (!allowed.contains(booking.status)) {
      throw StateError(
        'Booking ${booking.id} không thể chuyển trạng thái từ ${booking.status}.',
      );
    }
  }
}

List<MockCareTask> defaultTasksFor(String serviceName) {
  final normalized = serviceName.toLowerCase();
  final specificTasks = <String>[];

  if (normalized.contains('trẻ') || normalized.contains('bé')) {
    specificTasks.addAll([
      'Kiểm tra bữa ăn và dị ứng',
      'Hoạt động vui chơi phù hợp độ tuổi',
      'Vệ sinh cá nhân và thời gian nghỉ',
    ]);
  } else if (normalized.contains('dọn') || normalized.contains('việc nhà')) {
    specificTasks.addAll([
      'Xác nhận khu vực cần dọn dẹp',
      'Dọn dẹp theo checklist gia đình',
      'Kiểm tra và bàn giao đồ dùng',
    ]);
  } else if (normalized.contains('nấu')) {
    specificTasks.addAll([
      'Kiểm tra thực đơn và dị ứng',
      'Chuẩn bị bữa ăn',
      'Vệ sinh khu vực bếp',
    ]);
  } else {
    specificTasks.addAll([
      'Xác nhận tình trạng người được chăm sóc',
      'Hỗ trợ sinh hoạt theo kế hoạch',
      'Cập nhật ghi chú cho gia đình',
    ]);
  }

  return [
    const MockCareTask(title: 'Check-in tại địa điểm', isCompleted: true),
    ...specificTasks.map((title) => MockCareTask(title: title)),
    const MockCareTask(title: 'Gửi báo cáo và yêu cầu kết thúc ca'),
  ];
}
