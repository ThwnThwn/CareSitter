import 'package:caregiver_app/features/shifts/data/models/shift_mapper.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_checkin_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/live_tracking_controller.dart';

/// Quản lý state danh sách ca của caregiver.
///
/// Tải danh sách ca thật từ backend và gọi API mutations.
class ShiftListController extends StateNotifier<List<ShiftModel>> {
  final Ref _ref;
  Timer? _refreshTimer;
  StreamSubscription<BookingStatusChange>? _signalRSub;
  StreamSubscription<BookingOfferChange>? _offerSignalRSub;
  StreamSubscription<void>? _reconnectSignalRSub;
  StreamSubscription<Map<String, dynamic>>? _taskSignalRSub;
  int _refreshGeneration = 0;
  final Set<String> _pendingLifecycleIds = {};

  ShiftListController(this._ref) : super([]) {
    _init();
  }

  /// Lắng nghe BookingStatusChanged + CareTaskUpdated qua SignalR
  Future<void> _subscribeSignalR() async {
    final signalR = _ref.read(careSignalRProvider);
    await signalR.connect();
    if (!mounted) return;
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
          unawaited(loadTasks(shift.id).catchError((_) {}));
        }
      }
    });
    // Subscribe CareTaskUpdated — patch task realtime
    _taskSignalRSub?.cancel();
    _taskSignalRSub = signalR.onTaskUpdated.listen((event) {
      if (!mounted) return;
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
    if (_ref.read(authStateProvider).value?.isAuthenticated != true) return;
    refresh();
    _startRefreshPolling();
    _subscribeSignalR();
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
    if (!mounted) return;
    final generation = ++_refreshGeneration;
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
          generation != _refreshGeneration ||
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
          final mapped = mapShiftFromApi(item);
          return mapped.copyWith(tasks: previousTasks[mapped.id]);
        }).toList();
      } else {
        // Nếu caregiver mới chưa có ca nào trong DB, giữ danh sách rỗng hoặc ca mở
        state = [];
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('[ShiftListController] Lỗi tải ca trực: $e');
    }
  }

  Future<void> _runLifecycle(String id, Future<void> Function() action) async {
    if (!mounted) return;
    if (!_pendingLifecycleIds.add(id)) {
      throw const AppApiException(message: 'Ca đang được xử lý. Vui lòng chờ.');
    }
    try {
      await action();
    } finally {
      _pendingLifecycleIds.remove(id);
    }
  }

  Future<void> acceptBooking(String id) =>
      _runLifecycle(id, () => _performAcceptBooking(id));
  Future<void> declineBooking(String id, {String? reason}) =>
      _runLifecycle(id, () => _performDeclineBooking(id, reason: reason));
  Future<void> startEnRoute(String bookingId) =>
      _runLifecycle(bookingId, () => _performStartEnRoute(bookingId));
  Future<void> checkIn(String bookingId) =>
      _runLifecycle(bookingId, () => _performCheckIn(bookingId));
  Future<void> checkOut(String bookingId) =>
      _runLifecycle(bookingId, () => _performCheckOut(bookingId));
  Future<void> completeShift(String bookingId) =>
      _runLifecycle(bookingId, () => _performCompleteShift(bookingId));

  // ── Lifecycle actions ─────────────────────────────────────────────────────

  /// Caregiver chấp nhận ca
  Future<void> _performAcceptBooking(String id) async {
    try {
      await _shiftRepo.acceptBooking(id);
      await refresh();
      return;
    } catch (e) {
      // A rejected mutation commonly means this offer changed concurrently.
      // Refetch so stale cards disappear instead of inviting repeated taps.
      await refresh();
      // ignore: avoid_print
      print('[ShiftListController] acceptBooking error: $e');
      rethrow;
    }
  }

  /// Caregiver từ chối ca
  Future<void> _performDeclineBooking(String id, {String? reason}) async {
    try {
      await _shiftRepo.declineBooking(id, reason: reason);
    } catch (e) {
      await refresh();
      // ignore: avoid_print
      print('[ShiftListController] declineBooking error: $e');
      rethrow;
    }
    _removeShift(id);
  }

  /// Bắt đầu di chuyển đến nhà khách
  Future<void> _performStartEnRoute(String bookingId) async {
    try {
      await _shiftRepo.startEnRoute(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftListController] startEnRoute error: $e');
      rethrow;
    }
    if (!mounted) return;
    _updateStatus(bookingId, to: 'caregiver_en_route');
    await _ref.read(liveTrackingProvider.notifier).start(bookingId);
  }

  /// GPS check-in tại địa điểm → status: in_progress.
  /// The server is the final authority for the 50m geofence.
  Future<void> _performCheckIn(String bookingId) async {
    DateTime? actualStart;
    try {
      actualStart =
          await _ref.read(shiftCheckinControllerProvider).checkIn(bookingId);
      if (!mounted) return;
      _ref
          .read(liveTrackingProvider.notifier)
          .reconcileStatus(bookingId, 'in_progress');
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftListController] checkIn error: $e');
      rethrow;
    }
    if (!mounted) return;
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
    return _ref
        .read(shiftCheckinControllerProvider)
        .uploadSelfie(bookingId, image);
  }

  /// Yêu cầu kết thúc ca → booking status chuyển sang checkout_pending_review
  Future<void> _performCheckOut(String bookingId) async {
    try {
      await _shiftRepo.requestCheckout(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftListController] checkOut error: $e');
      rethrow;
    }
    if (!mounted) return;
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
  Future<void> _performCompleteShift(String bookingId) async {
    try {
      await _shiftRepo.completeBooking(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftListController] completeShift error: $e');
      return;
    }
    if (!mounted) return;
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
      print('[ShiftListController] loadTasks error: $e');
      rethrow;
    }
  }

  Future<void> completeTask(String bookingId, String taskId) async {
    try {
      final raw = await _shiftRepo.completeTask(bookingId, taskId);
      _replaceTask(bookingId, CareTaskModel.fromApi(raw));
    } catch (e) {
      // ignore: avoid_print
      print('[ShiftListController] completeTask error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadTaskPhoto(
      String bookingId, String taskId, XFile image) async {
    final raw = await _shiftRepo.uploadTaskPhoto(bookingId, taskId, image);
    if (!mounted) return raw;
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
      print('[ShiftListController] skipTask error: $e');
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
      print('[ShiftListController] createTask error: $e');
      rethrow;
    }
  }

  void _replaceTasks(String bookingId, List<CareTaskModel> tasks) {
    if (!mounted) return;
    state = [
      for (final b in state)
        if (b.id == bookingId) b.copyWith(tasks: tasks) else b,
    ];
  }

  void _replaceTask(String bookingId, CareTaskModel task) {
    if (!mounted) return;
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
    if (!mounted) return;
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _updateStatus(String id, {required String to}) {
    if (!mounted) return;
    state = [
      for (final b in state)
        if (b.id == id) b.copyWith(status: to) else b,
    ];
  }

  void _removeShift(String id) {
    if (!mounted) return;
    state = [
      for (final b in state)
        if (b.id != id) b,
    ];
  }

  @override
  void dispose() {
    _refreshGeneration++;
    _stopRefreshPolling();
    _signalRSub?.cancel();
    _offerSignalRSub?.cancel();
    _reconnectSignalRSub?.cancel();
    _taskSignalRSub?.cancel();
    super.dispose();
  }
}

final shiftsProvider =
    StateNotifierProvider<ShiftListController, List<ShiftModel>>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return ShiftListController(ref);
});
