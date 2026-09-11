import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/realtime/care_signalr_service.dart';
import '../../data/gps_repository.dart';
import '../../data/shift_model.dart';
import '../../data/shift_repository.dart';

/// ShiftsNotifier — quản lý state danh sách ca của caregiver.
///
/// Tải danh sách ca thật từ backend và gọi API mutations.
class ShiftsNotifier extends StateNotifier<List<ShiftModel>> {
  final Ref _ref;
  Timer? _gpsTimer;
  Timer? _refreshTimer;
  StreamSubscription<BookingStatusChange>? _signalRSub;

  ShiftsNotifier(this._ref) : super([]) {
    _ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        refresh();
        _startRefreshPolling();
        _subscribeSignalR();
      } else {
        state = [];
        _stopRefreshPolling();
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
    refresh();
    _startRefreshPolling();
  }

  void _startRefreshPolling() {
    if (_refreshTimer != null) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refresh();
    });
  }

  void _stopRefreshPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
      final previousTasks = <String, List<CareTaskModel>>{
        for (final shift in state)
          if (shift.tasks.isNotEmpty) shift.id: shift.tasks,
      };
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...rawAssignedShifts, ...rawOpenOffers]) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          merged[id] = item;
        }
      }

      if (merged.isNotEmpty) {
        state = merged.values.map((item) {
          final mapped = _mapFromApi(item);
          return mapped.copyWith(tasks: previousTasks[mapped.id]);
        }).toList();
      } else {
        // Nếu caregiver mới chưa có ca nào trong DB, giữ danh sách rỗng hoặc ca mở
        state = [];
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] Lỗi tải ca trực: $e');
    }
  }

  // ── Lifecycle actions ─────────────────────────────────────────────────────

  /// Caregiver chấp nhận ca
  Future<void> acceptBooking(String id) async {
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

  /// Caregiver từ chối ca
  Future<void> declineBooking(String id) async {
    try {
      await _shiftRepo.declineBooking(id);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] declineBooking error: $e');
      rethrow;
    }
    _removeShift(id);
  }

  /// Bắt đầu di chuyển đến nhà khách
  Future<void> startEnRoute(String bookingId) async {
    try {
      await _shiftRepo.startEnRoute(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] startEnRoute error: $e');
      rethrow;
    }
    _updateStatus(bookingId, to: 'caregiver_en_route');
    _startGpsPush(bookingId);
  }

  /// GPS check-in tại địa điểm → status: in_progress.
  /// The server is the final authority for the 50m geofence.
  Future<void> checkIn(String bookingId) async {
    DateTime? actualStart;
    try {
      final position = await _getCurrentPosition();
      final raw = await _shiftRepo.checkIn(
        bookingId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      actualStart =
          DateTime.tryParse(raw['actualStart']?.toString() ?? '')?.toLocal();
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] checkIn error: $e');
      rethrow;
    }
    _stopGpsPush();
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(
              status: 'in_progress', actualStart: actualStart ?? DateTime.now())
        else
          b,
    ];
  }

  /// Yêu cầu kết thúc ca → booking status chuyển sang checkout_pending_review
  Future<void> checkOut(String bookingId) async {
    try {
      await _shiftRepo.requestCheckout(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] checkOut error: $e');
      return;
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
    try {
      await _shiftRepo.completeBooking(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] completeShift error: $e');
      return;
    }
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(status: 'completed', completedAt: DateTime.now())
        else
          b,
    ];
  }

  Future<void> addTimelineNote(String bookingId, String note) async {
    if (note.trim().isEmpty) return;
    await _shiftRepo.addTimelineNote(bookingId, note.trim());
  }

  Future<void> raiseSos(String bookingId) async {
    await _shiftRepo.raiseSos(bookingId);
    _updateStatus(bookingId, to: 'crisis');
  }

  Future<void> loadTasks(String bookingId) async {
    try {
      final rawTasks = await _shiftRepo.getTasks(bookingId);
      final tasks = rawTasks.map(CareTaskModel.fromApi).toList();
      _replaceTasks(bookingId, tasks);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] loadTasks error: $e');
      rethrow;
    }
  }

  Future<void> completeTask(String bookingId, String taskId) async {
    try {
      final raw = await _shiftRepo.completeTask(bookingId, taskId);
      _replaceTask(bookingId, CareTaskModel.fromApi(raw));
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] completeTask error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadTaskPhoto(
      String bookingId, String taskId, XFile image) async {
    final raw = await _shiftRepo.uploadTaskPhoto(bookingId, taskId, image);
    final task = state
        .firstWhere((booking) => booking.id == bookingId)
        .tasks
        .firstWhere((task) => task.id == taskId);
    final url = raw['url']?.toString();
    if (url != null && url.isNotEmpty) {
      _replaceTask(
          bookingId,
          task.copyWith(photoUrls: [
            ...task.photoUrls,
            url,
          ]));
    }
    return raw;
  }

  Future<void> skipTask(String bookingId, String taskId) async {
    try {
      final raw = await _shiftRepo.skipTask(bookingId, taskId);
      _replaceTask(bookingId, CareTaskModel.fromApi(raw));
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] skipTask error: $e');
      rethrow;
    }
  }

  void _replaceTasks(String bookingId, List<CareTaskModel> tasks) {
    state = [
      for (final b in state)
        if (b.id == bookingId) b.copyWith(tasks: tasks) else b,
    ];
  }

  void _replaceTask(String bookingId, CareTaskModel task) {
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(tasks: [
            for (final current in b.tasks)
              if (current.id == task.id) task else current,
          ])
        else
          b,
    ];
  }

  // ── GPS push (background timer) ───────────────────────────────────────────

  void _startGpsPush(String bookingId) {
    _stopGpsPush();

    _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final position = await _getCurrentPosition();
        await _gps.postLocation(
          bookingId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          speed: position.speed >= 0 ? position.speed : null,
          heading: position.heading >= 0 ? position.heading : null,
        );
      } catch (_) {
        // GPS/network can recover on the next foreground poll.
      }
    });
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException(
        'Hãy bật Dịch vụ vị trí để check-in.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException(
        'Cần cấp quyền vị trí để check-in.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException(
        'Quyền vị trí đang bị tắt. Hãy bật lại trong phần Cài đặt của thiết bị.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
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

  void _removeShift(String id) {
    state = [
      for (final b in state)
        if (b.id != id) b,
    ];
  }

  ShiftModel _mapFromApi(Map<String, dynamic> json) {
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
    // Dùng số tiền backend chốt; fallback chỉ để tương thích API cũ.
    final earning = (json['caregiverEarningAmount'] as num?)?.toDouble() ??
        (escrow > 0 ? (escrow - fee) : 0.0);

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

    DateTime? checkoutRequestedAt;
    if (json['checkoutPendingReviewAt'] != null) {
      checkoutRequestedAt =
          DateTime.tryParse(json['checkoutPendingReviewAt'].toString())
              ?.toLocal();
    } else if (json['actualEnd'] != null) {
      checkoutRequestedAt =
          DateTime.tryParse(json['actualEnd'].toString())?.toLocal();
    }

    DateTime? completedAt;
    if (json['updatedAt'] != null && mappedStatus == 'completed') {
      completedAt = DateTime.tryParse(json['updatedAt'].toString())?.toLocal();
    }

    final int? beneficiaryAge = (json['beneficiaryAge'] as num?)?.toInt();
    final String? beneficiaryRelationship =
        json['beneficiaryRelationship']?.toString();
    final String? beneficiaryCondition =
        json['beneficiaryCondition']?.toString();
    final String? beneficiaryNotes =
        json['beneficiaryNotes']?.toString() ?? json['note']?.toString();

    DateTime? actualStart;
    if (json['actualStart'] != null) {
      actualStart =
          DateTime.tryParse(json['actualStart'].toString())?.toLocal();
    }

    return ShiftModel(
      id: id,
      beneficiaryId: json['beneficiaryId']?.toString(),
      beneficiaryName: _displayText(
        json['beneficiaryName'],
        fallback: _shortIdLabel('Người thân', json['beneficiaryId']),
      ),
      caregiverId: json['caregiverId']?.toString(),
      caregiverName: _displayText(json['caregiverName'], fallback: 'Caregiver'),
      caregiverAvatar:
          _initials(_displayText(json['caregiverName'], fallback: 'CG')),
      serviceId: json['serviceTypeId']?.toString(),
      serviceName: _displayText(
        json['serviceName'],
        fallback: 'Dịch vụ chưa cập nhật',
      ),
      serviceDescription: _nullableDisplayText(json['serviceDescription']),
      date: dateStr,
      time: timeStr,
      duration: durationStr,
      scheduledStart: start,
      scheduledEnd: end,
      status: mappedStatus,
      totalPrice: escrow,
      caregiverEarning: earning,
      address: _displayText(
        json['addressText'],
        fallback: 'Địa chỉ khách hàng đã đăng ký',
      ),
      addressLatitude: (json['addressLatitude'] as num?)?.toDouble(),
      addressLongitude: (json['addressLongitude'] as num?)?.toDouble(),
      customerNote: _displayText(json['note'], fallback: ''),
      isSystemMatched: json['caregiverId'] != null,
      actualStart: actualStart,
      checkoutRequestedAt: checkoutRequestedAt,
      completedAt: completedAt,
      beneficiaryAge: beneficiaryAge,
      beneficiaryRelationship: beneficiaryRelationship,
      beneficiaryCondition: beneficiaryCondition,
      beneficiaryNotes: beneficiaryNotes,
      tasks: const [],
    );
  }

  String _displayText(Object? value, {required String fallback}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _nullableDisplayText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _shortIdLabel(String label, Object? rawId) {
    final id = rawId?.toString();
    if (id == null || id.isEmpty) return label;
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return '$label (ID: $shortId)';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CG';
    if (parts.length == 1) {
      final take = parts.first.length < 2 ? parts.first.length : 2;
      return parts.first.substring(0, take).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  void dispose() {
    _stopGpsPush();
    _stopRefreshPolling();
    super.dispose();
  }
}

class LocationUnavailableException implements Exception {
  final String message;
  const LocationUnavailableException(this.message);

  @override
  String toString() => message;
}

final shiftsProvider =
    StateNotifierProvider<ShiftsNotifier, List<ShiftModel>>((ref) {
  return ShiftsNotifier(ref);
});
