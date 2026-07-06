import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/mock/mock_data.dart';

class ShiftsNotifier extends StateNotifier<List<MockBooking>> {
  ShiftsNotifier() : super([]) {
    _init();
  }

  void _init() {
    state = [
      const MockBooking(
        id: 'bk001',
        beneficiaryName: 'Nguyễn Văn An',
        caregiverName: 'Phạm Thị Bích Ngọc',
        caregiverAvatar: 'PBN',
        serviceName: 'Đồng hành ban ngày',
        date: 'Hôm nay, 26/06/2026',
        time: '08:00 - 12:00',
        duration: '4 giờ',
        status: 'in_progress',
        totalPrice: 340000,
        caregiverEarning: 290000,
        address: '123 Nguyễn Trãi, P.2, Q.5, TP.HCM',
        tasks: [
          MockCareTask(title: 'Đo huyết áp', isCompleted: false),
          MockCareTask(title: 'Nhắc uống thuốc', isCompleted: false),
          MockCareTask(title: 'Ăn trưa', isCompleted: false),
        ],
      ),
      const MockBooking(
        id: 'bk002',
        beneficiaryName: 'Trần Thị Hoa',
        caregiverName: 'Lê Văn Hùng',
        caregiverAvatar: 'LVH',
        serviceName: 'Hỗ trợ sinh hoạt & dọn dẹp',
        date: 'Ngày mai, 27/06/2026',
        time: '09:00 - 11:00',
        duration: '2 giờ',
        status: 'confirmed',
        totalPrice: 150000,
        caregiverEarning: 130000,
        address: '45 Lê Lợi, P.7, Q.3, TP.HCM',
        tasks: [
          MockCareTask(title: 'Chuẩn bị bữa ăn trưa', isCompleted: false),
          MockCareTask(title: 'Giúp tắm gội', isCompleted: false),
          MockCareTask(title: 'Dọn dẹp phòng khách', isCompleted: false),
        ],
      ),
      const MockBooking(
        id: 'bk003',
        beneficiaryName: 'Bé Minh Khang',
        caregiverName: 'Trần Thị Thanh Mai',
        caregiverAvatar: 'TTM',
        serviceName: 'Trông trẻ cả ngày',
        date: 'T6, 28/06/2026',
        time: '07:00 - 19:00',
        duration: '12 giờ',
        status: 'pending',
        totalPrice: 1140000,
        caregiverEarning: 970000,
        address: '123 Nguyễn Trãi, P.2, Q.5, TP.HCM',
        tasks: [
          MockCareTask(title: 'Cho bé ăn trưa', isCompleted: false),
          MockCareTask(title: 'Cho bé ngủ trưa', isCompleted: false),
          MockCareTask(title: 'Chơi xếp hình cùng bé', isCompleted: false),
        ],
      ),
      MockBooking(
        id: 'bk004',
        beneficiaryName: 'Nguyễn Văn An',
        caregiverName: 'Nguyễn Thị Hồng Nhung',
        caregiverAvatar: 'NHN',
        serviceName: 'Đồng hành & đưa đón',
        date: '20/06/2026',
        time: '08:00 - 16:00',
        duration: '8 giờ',
        status: 'completed',
        totalPrice: 560000,
        caregiverEarning: 480000,
        address: '78 Cách Mạng Tháng 8, Q.10, TP.HCM',
        completedAt: DateTime(2026, 6, 20, 16, 0),
        tasks: const [
          MockCareTask(title: 'Đưa đi khám bệnh', isCompleted: true),
          MockCareTask(title: 'Mua thuốc theo toa', isCompleted: true),
        ],
      ),
      MockBooking(
        id: 'bk005',
        beneficiaryName: 'Trần Thị Hoa',
        caregiverName: 'Phạm Thị Bích Ngọc',
        caregiverAvatar: 'PBN',
        serviceName: 'Đồng hành ban ngày',
        date: '15/06/2026',
        time: '08:00 - 12:00',
        duration: '4 giờ',
        status: 'completed',
        totalPrice: 340000,
        caregiverEarning: 290000,
        address: '45 Lê Lợi, P.7, Q.3, TP.HCM',
        completedAt: DateTime(2026, 6, 15, 12, 0),
        tasks: const [
          MockCareTask(title: 'Hỗ trợ tập vật lý trị liệu', isCompleted: true),
          MockCareTask(title: 'Nấu súp gà', isCompleted: true),
        ],
      ),
    ];
  }

  void acceptBooking(String id) {
    state = [
      for (final booking in state)
        if (booking.id == id)
          booking.copyWith(status: 'confirmed')
        else
          booking
    ];
  }

  void declineBooking(String id) {
    state = [
      for (final booking in state)
        if (booking.id == id)
          booking.copyWith(status: 'declined')
        else
          booking
    ];
  }

  void checkIn(String id) {
    state = [
      for (final booking in state)
        if (booking.id == id)
          booking.copyWith(status: 'in_progress')
        else
          booking
    ];
  }

  void toggleTask(String bookingId, String taskTitle, bool done) {
    state = [
      for (final booking in state)
        if (booking.id == bookingId)
          booking.copyWith(
            tasks: [
              for (final task in booking.tasks)
                if (task.title == taskTitle)
                  task.copyWith(isCompleted: done)
                else
                  task
            ],
          )
        else
          booking
    ];
  }

  void checkOut(String bookingId) {
    state = [
      for (final booking in state)
        if (booking.id == bookingId)
          booking.copyWith(
            status: 'completed',
            completedAt: DateTime.now(),
          )
        else
          booking
    ];
  }
}

final shiftsProvider = StateNotifierProvider<ShiftsNotifier, List<MockBooking>>((ref) {
  return ShiftsNotifier();
});
