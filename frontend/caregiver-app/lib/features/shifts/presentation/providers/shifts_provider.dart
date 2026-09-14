import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/realtime/care_signalr_service.dart';
import '../../data/shift_model.dart';
import '../../data/shift_repository.dart';

/// ShiftsNotifier — quản lý state danh sách ca của caregiver.
///
/// Tải danh sách ca thật từ backend và gọi API mutations.
class ShiftsNotifier extends StateNotifier<List<ShiftModel>> {
  final Ref _ref;
  Timer? _refreshTimer;
  StreamSubscription<BookingStatusChange>? _signalRSub;
  StreamSubscription<BookingOfferChange>? _offerSignalRSub;
  StreamSubscription<void>? _reconnectSignalRSub;

  ShiftsNotifier(this._ref) : super([]) {
    _ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      // Refresh tokens do not change which user's data needs loading.
      if (isAuth &&
          prev?.value?.isAuthenticated == true &&
          prev?.value?.userId == next.value?.userId) {
        return;
      }
      if (isAuth) {
        refresh();
        _startRefreshPolling();
        _subscribeSignalR();
      } else {
        state = [];
        _stopRefreshPolling();
        _signalRSub?.cancel();
        _offerSignalRSub?.cancel();
        _reconnectSignalRSub?.cancel();
      }
    });
    _init();
  }

  /// Lắng nghe BookingStatusChanged + CareTaskUpdated qua SignalR
  Future<void> _subscribeSignalR() async {
    final signalR = _ref.read(careSignalRProvider);
    await signalR.connect();
    _signalRSub?.cancel();
    _signalRSub = signalR.statusStream.listen((_) {
      // Bất kỳ booking nào đổi trạng thái → refresh list
      refresh();
    });
    _offerSignalRSub?.cancel();
    _offerSignalRSub = signalR.offerStream.listen((_) {
      // SignalR sends a hint only; a refetch prevents partial/stale offers.
      refresh();
    });
    _reconnectSignalRSub?.cancel();
    _reconnectSignalRSub = signalR.onReconnected.listen((_) {
      // Recover any updates missed while the device was offline.
      refresh();
      // Reload tasks cho ca đang in_progress
      for (final shift in state) {
        if (shift.status == 'in_progress') {
          loadTasks(shift.id);
        }
      }
    });
    // Subscribe CareTaskUpdated — patch task realtime
    signalR.onTaskUpdated.listen((event) {
      final bookingId = event['bookingId']?.toString();
      final taskJson = event['task'];
      if (bookingId == null || taskJson == null) return;
      try {
        final task = CareTaskModel.fromApi(taskJson as Map<String, dynamic>);
        _upsertTask(bookingId, task);
      } catch (_) {}
    });
  }

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
      final userId = _ref.read(authStateProvider).value?.userId;
      final results = await Future.wait([
        _shiftRepo.getShifts(pageSize: 50),
        _shiftRepo.getOpenOffers(pageSize: 20),
      ]);
      if (!mounted ||
          _ref.read(authStateProvider).value?.isAuthenticated != true ||
          _ref.read(authStateProvider).value?.userId != userId) {
        return;
      }
      final rawAssignedShifts = results[0];
      final rawOpenOffers = results[1];
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
      // A rejected mutation commonly means this offer changed concurrently.
      // Refetch so stale cards disappear instead of inviting repeated taps.
      await refresh();
      // ignore: avoid_print
      print('[ShiftsNotifier] acceptBooking error: $e');
      rethrow;
    }
  }

  /// Caregiver từ chối ca
  Future<void> declineBooking(String id, {String? reason}) async {
    try {
      await _shiftRepo.declineBooking(id, reason: reason);
    } catch (e) {
      await refresh();
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
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(
              status: 'in_progress', actualStart: actualStart ?? DateTime.now())
        else
          b,
    ];
  }

  Future<String> uploadCheckInSelfie(String bookingId, XFile image) async {
    final raw = await _shiftRepo.uploadCheckInSelfie(bookingId, image);
    final url = raw['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Máy chủ không trả về ảnh selfie.');
    }
    return url;
  }

  /// Yêu cầu kết thúc ca → booking status chuyển sang checkout_pending_review
  Future<void> checkOut(String bookingId) async {
    try {
      await _shiftRepo.requestCheckout(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] checkOut error: $e');
      rethrow;
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

  Future<void> skipTask(String bookingId, String taskId, String reason) async {
    try {
      final raw = await _shiftRepo.skipTask(bookingId, taskId, reason);
      _replaceTask(bookingId, CareTaskModel.fromApi(raw));
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] skipTask error: $e');
      rethrow;
    }
  }

  Future<void> createTask(String bookingId, String name,
      {String? description}) async {
    try {
      final raw = await _shiftRepo.createTask(bookingId, name,
          description: description);
      final task = CareTaskModel.fromApi(raw);
      _upsertTask(bookingId, task);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftsNotifier] createTask error: $e');
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

  /// Upsert: nếu task đã có thì replace, nếu chưa có (ad-hoc mới) thì append.
  void _upsertTask(String bookingId, CareTaskModel task) {
    state = [
      for (final b in state)
        if (b.id == bookingId)
          () {
            final existing = b.tasks.indexWhere((t) => t.id == task.id);
            if (existing >= 0) {
              return b.copyWith(tasks: [
                for (final t in b.tasks)
                  if (t.id == task.id) task else t,
              ]);
            } else {
              return b.copyWith(tasks: [...b.tasks, task]);
            }
          }()
        else
          b,
    ];
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
      offerId: json['offerId']?.toString(),
      offerExpiresAt: json['offerExpiresAt'] == null
          ? null
          : DateTime.tryParse(json['offerExpiresAt'].toString())?.toLocal(),
      offerRank: (json['offerRank'] as num?)?.toInt(),
      isSystemMatched: json['caregiverId'] != null,
      actualStart: actualStart,
      checkoutRequestedAt: checkoutRequestedAt,
      completedAt: completedAt,
      beneficiaryAge: beneficiaryAge,
      beneficiaryRelationship: beneficiaryRelationship,
      beneficiaryCondition: beneficiaryCondition,
      beneficiaryNotes: beneficiaryNotes,
      tasks: const [],
      allowAdHocTasks: json['allowAdHocTasks'] as bool? ?? false,
      needsReview: json['needsReview'] as bool? ?? false,
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
    _stopRefreshPolling();
    _signalRSub?.cancel();
    _offerSignalRSub?.cancel();
    _reconnectSignalRSub?.cancel();
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
