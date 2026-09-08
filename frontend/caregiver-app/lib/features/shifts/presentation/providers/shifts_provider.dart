import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/mock/mock_data.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/realtime/care_signalr_service.dart';
import '../../data/gps_repository.dart';
import '../../data/shift_repository.dart';

/// ShiftsNotifier — quản lý state danh sách ca của caregiver.
///
/// kDebugBypassAuth=true  → dùng mock data, actions chỉ thay state local.
/// kDebugBypassAuth=false → tải danh sách ca thật từ backend và gọi API mutations.
class ShiftsNotifier extends StateNotifier<List<MockBooking>> {
  final Ref _ref;
  Timer? _gpsTimer;
  StreamSubscription<BookingStatusChange>? _signalRSub;

  ShiftsNotifier(this._ref) : super([]) {
    _ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        refresh();
        _subscribeSignalR();
      } else {
        state = [];
        _signalRSub?.cancel();
      }
    });
    _init();
  }

  /// Lắng nghe BookingStatusChanged qua SignalR —
  /// khi backend có sự kiện (auto-complete, cancel, check-in)
  /// thì tự động refresh danh sách ca.
  Future<void> _subscribeSignalR() async {
    final signalR = _ref.read(careSignalRProvider);
    await signalR.connect();
    _signalRSub?.cancel();
    _signalRSub = signalR.statusStream.listen((_) {
      // Bất kỳ booking nào đổi trạng thái → refresh list
      refresh();
    });
  }

  GpsRepository get _gps => _ref.read(gpsRepositoryProvider);
  ShiftRepository get _shiftRepo => _ref.read(shiftRepositoryProvider);

  void _init() {
    if (kDebugBypassAuth) {
      state = _getSampleShifts();
    } else {
      refresh();
    }
  }

  /// Tải danh sách ca từ backend
  Future<void> refresh() async {
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) {
      state = [];
      return;
    }

    try {
      final rawAssignedShifts = await _shiftRepo.getShifts(pageSize: 50);
      final rawOpenOffers = await _shiftRepo.getOpenOffers(pageSize: 20);
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...rawAssignedShifts, ...rawOpenOffers]) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          merged[id] = item;
        }
      }

      if (merged.isNotEmpty) {
        state = merged.values.map(_mapFromApi).toList();
      } else {
        // Nếu caregiver mới chưa có ca nào trong DB, giữ danh sách rỗng hoặc ca mở
        state = [];
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] Lỗi tải ca trực: $e');
      // Nếu lỗi network, giữ state cũ nếu có
      if (state.isEmpty && kDebugBypassAuth) {
        state = _getSampleShifts();
      }
    }
  }

  // ── Lifecycle actions ─────────────────────────────────────────────────────

  /// Caregiver chấp nhận ca
  Future<void> acceptBooking(String id) async {
    if (!kDebugBypassAuth) {
      try {
        await _shiftRepo.acceptBooking(id);
        await refresh();
        return;
      } catch (e) {
        // ignore: avoid_print
        print('[ShiftsNotifier] acceptBooking error: $e');
        rethrow;
      }
    }
    _updateStatus(id, to: 'confirmed');
  }

  /// Caregiver từ chối ca
  Future<void> declineBooking(String id) async {
    _updateStatus(id, to: 'declined');
  }

  /// Bắt đầu di chuyển đến nhà khách
  Future<void> startEnRoute(String bookingId) async {
    if (!kDebugBypassAuth) {
      try {
        await _shiftRepo.startEnRoute(bookingId);
      } catch (e) {
        // ignore: avoid_print
        print('[ShiftsNotifier] startEnRoute error: $e');
        return;
      }
    }
    _updateStatus(bookingId, to: 'caregiver_en_route');
    _startGpsPush(bookingId);
  }

  /// GPS check-in tại địa điểm → status: in_progress
  Future<void> checkIn(
    String bookingId, {
    double latitude = 10.7769,
    double longitude = 106.6952,
    double? accuracy,
  }) async {
    if (!kDebugBypassAuth) {
      try {
        await _shiftRepo.checkIn(
          bookingId,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracy,
        );
      } catch (e) {
        // ignore: avoid_print
        print('[ShiftsNotifier] checkIn error: $e');
        return;
      }
    }
    _stopGpsPush();
    _updateStatus(bookingId, to: 'in_progress');
  }

  /// Yêu cầu kết thúc ca → booking status chuyển sang checkout_pending_review
  Future<void> checkOut(String bookingId) async {
    if (!kDebugBypassAuth) {
      try {
        await _shiftRepo.requestCheckout(bookingId);
      } catch (e) {
        // ignore: avoid_print
        print('[ShiftsNotifier] checkOut error: $e');
        return;
      }
    }
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(
            // BE trả checkout_pending_review — không dùng alias checkout_requested nữa
            status: 'checkout_pending_review',
            checkoutRequestedAt: DateTime.now(),
          )
        else
          b,
    ];
  }

  /// Hoàn tất ca
  Future<void> completeShift(String bookingId) async {
    if (!kDebugBypassAuth) {
      try {
        await _shiftRepo.completeBooking(bookingId);
      } catch (e) {
        // ignore: avoid_print
        print('[ShiftsNotifier] completeShift error: $e');
        return;
      }
    }
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(status: 'completed', completedAt: DateTime.now())
        else
          b,
    ];
  }

  void toggleTask(String bookingId, String taskTitle, bool done) {
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(tasks: [
            for (final t in b.tasks)
              if (t.title == taskTitle) t.copyWith(isCompleted: done) else t,
          ])
        else
          b,
    ];
  }

  // ── GPS push (background timer) ───────────────────────────────────────────

  void _startGpsPush(String bookingId) {
    _stopGpsPush();
    if (kDebugBypassAuth) return;

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      const lat = 10.7650;
      const lng = 106.6800;
      try {
        await _gps.postLocation(bookingId,
            latitude: lat, longitude: lng, heading: 45.0);
      } catch (_) {
        // Bỏ qua lỗi network
      }
    });
  }

  void _stopGpsPush() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _updateStatus(String id, {required String to}) {
    state = [
      for (final b in state)
        if (b.id == id) b.copyWith(status: to) else b,
    ];
  }

  MockBooking _mapFromApi(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final rawStatus = json['status']?.toString().toLowerCase() ?? 'pending';

    String mappedStatus = rawStatus;
    if (rawStatus == 'payment_confirmed' || rawStatus == 'confirmed') {
      mappedStatus = 'pending';
    } else if (rawStatus == 'caregiver_accepted' || rawStatus == 'assigned') {
      mappedStatus = 'confirmed';
    } else if (rawStatus == 'caregiver_en_route' || rawStatus == 'en_route') {
      mappedStatus = 'caregiver_en_route';
    } else if (rawStatus == 'in_progress') {
      mappedStatus = 'in_progress';
    } else if (rawStatus == 'checkout_pending_review') {
      mappedStatus = 'checkout_pending_review';
    } else if (rawStatus == 'completed') {
      mappedStatus = 'completed';
    } else if (rawStatus == 'cancelled') {
      mappedStatus = 'cancelled';
    } else if (rawStatus == 'pending_payment' || rawStatus == 'draft') {
      mappedStatus = rawStatus;
    }

    final escrow = (json['escrowAmount'] as num?)?.toDouble() ?? 0.0;
    final fee = (json['platformFeeAmount'] as num?)?.toDouble() ?? 0.0;
    final earning = escrow > 0 ? (escrow - fee) : 0.0;

    DateTime? start;
    if (json['scheduledStart'] != null) {
      start = DateTime.tryParse(json['scheduledStart'].toString())?.toLocal();
    }
    DateTime? end;
    if (json['scheduledEnd'] != null) {
      end = DateTime.tryParse(json['scheduledEnd'].toString())?.toLocal();
    }

    String dateStr = 'Hôm nay';
    String timeStr = '08:00 - 12:00';
    String durationStr = '4 giờ';
    if (start != null) {
      dateStr =
          '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
      if (end != null) {
        timeStr =
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        final diffHours = end.difference(start).inHours;
        durationStr = '$diffHours giờ';
      }
    }

    return MockBooking(
      id: id,
      beneficiaryId: json['beneficiaryId']?.toString(),
      beneficiaryName:
          'Người thân (ID: ${json['beneficiaryId']?.toString().substring(0, 8) ?? ""})',
      caregiverId: json['caregiverId']?.toString(),
      caregiverName: 'Caregiver',
      caregiverAvatar: 'CG',
      serviceId: json['serviceTypeId']?.toString(),
      serviceName: 'Gói Chăm sóc Genki',
      date: dateStr,
      time: timeStr,
      duration: durationStr,
      status: mappedStatus,
      totalPrice: escrow,
      caregiverEarning: earning,
      address: 'Địa chỉ khách hàng đã đăng ký',
      tasks: const [
        MockCareTask(
            title: 'Đo huyết áp & kiểm tra sức khoẻ', isCompleted: false),
        MockCareTask(
            title: 'Hỗ trợ vệ sinh sinh hoạt cá nhân', isCompleted: false),
        MockCareTask(title: 'Nhắc uống thuốc theo toa', isCompleted: false),
        MockCareTask(title: 'Chuẩn bị bữa ăn dinh dưỡng', isCompleted: false),
      ],
    );
  }

  List<MockBooking> _getSampleShifts() => [
        const MockBooking(
          id: 'bk001',
          beneficiaryName: 'Nguyễn Văn An',
          caregiverName: 'Phạm Thị Bích Ngọc',
          caregiverAvatar: 'PBN',
          serviceName: 'Gói Dưỡng - Hỗ trợ sinh hoạt',
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
          serviceName: 'Gói An - Kích hoạt trí não',
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
          serviceName: 'Gói Tâm - Toàn diện 1:1',
          date: 'T6, 28/06/2026',
          time: '07:00 - 19:00',
          duration: '12 giờ',
          status: 'pending',
          totalPrice: 1140000,
          caregiverEarning: 970000,
          address: '123 Nguyễn Trãi, P.2, Q.5, TP.HCM',
          tasks: [
            MockCareTask(title: 'Hỗ trợ ăn uống', isCompleted: false),
            MockCareTask(title: 'Nhắc giờ ngủ', isCompleted: false),
            MockCareTask(title: 'Vận động nhẹ', isCompleted: false),
          ],
        ),
      ];

  @override
  void dispose() {
    _stopGpsPush();
    super.dispose();
  }
}

final shiftsProvider =
    StateNotifierProvider<ShiftsNotifier, List<MockBooking>>((ref) {
  return ShiftsNotifier(ref);
});
