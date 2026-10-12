import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/domain/shift_active_rules.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_checkin_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_state.dart';
import 'package:caregiver_app/features/shifts/presentation/models/shift_action_result.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_actions.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/riverpod_shift_active_actions.dart';

final shiftActiveProvider = StateNotifierProvider.autoDispose
    .family<ShiftActiveController, ShiftActiveState, String>((ref, id) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final controller = ShiftActiveController(RiverpodShiftActiveActions(ref, id));
  ref.listen(shiftsProvider,
      (_, next) => controller.reconcile(next.where((b) => b.id == id).firstOrNull));
  Future.microtask(() {
    if (!controller.mounted) return;
    controller
        .reconcile(ref.read(shiftsProvider).where((b) => b.id == id).firstOrNull);
    controller.loadTasks();
  });
  return controller;
});

class ShiftActiveController extends StateNotifier<ShiftActiveState> {
  ShiftActiveController(this.actions,
      {DateTime Function()? now, this.enableTimer = true})
      : _now = now ?? DateTime.now,
        super(const ShiftActiveState());
  final ShiftActiveActions actions;
  final DateTime Function() _now;
  final bool enableTimer;
  Timer? _timer;
  bool _tasksLoaded = false;
  int _generation = 0;
  bool _current(int generation) => mounted && generation == _generation;
  void reconcile(ShiftModel? booking) {
    if (!mounted || booking == null) return;
    if (booking.status != 'in_progress') {
      _timer?.cancel();
      _timer = null;
    }
    final checkedIn = ShiftActiveRules.isCheckedIn(booking.status);
    if (!checkedIn) return;
    final now = _now();
    final rawStart =
        (booking.actualStart ?? booking.scheduledStart ?? now).toLocal();
    final start = rawStart.isAfter(now) ? now : rawStart;
    state = state.copyWith(
        checkedIn: true,
        step: 3,
        startedAt: start,
        elapsed:
            ShiftActiveRules.elapsed(start, booking.checkoutRequestedAt ?? now));
    if (booking.status == 'in_progress' && enableTimer) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void tick() {
    if (!mounted || state.startedAt == null) return;
    state =
        state.copyWith(elapsed: ShiftActiveRules.elapsed(state.startedAt!, _now()));
  }

  Future<void> loadTasks() async {
    if (_tasksLoaded || !mounted) return;
    _tasksLoaded = true;
    final result = await _run('load', actions.loadTasks);
    if (result is ShiftActionFailure && mounted) {
      _tasksLoaded = false;
      state = state.copyWith(error: result.message);
    }
  }

  void startCheckIn() {
    if (actions.snapshot?.canCheckIn == true) state = state.copyWith(step: 1);
  }

  void setNote(String value) => state = state.copyWith(note: value);
  Future<ShiftActionResult> uploadSelfie(XFile image) => _run('selfie', () async {
        final url = await actions.uploadSelfie(image);
        if (url.isEmpty) {
          throw const AppApiException(message: 'Máy chủ chưa trả về ảnh selfie.');
        }
        if (mounted) state = state.copyWith(selfieUrl: url, step: 2);
      });
  Future<ShiftActionResult> checkIn() => _run('checkin', () async {
        if (actions.snapshot?.canCheckIn != true || state.selfieUrl == null) {
          throw const AppApiException(
              message:
                  'Vui lòng tải selfie và kiểm tra trạng thái ca trước khi xác nhận GPS.');
        }
        await actions.checkIn();
        if (mounted) reconcile(actions.snapshot);
      });
  Future<ShiftActionResult> completeTask(String id) => _run('task:$id', () async {
        final task = actions.snapshot?.tasks.where((t) => t.id == id).firstOrNull;
        if (actions.snapshot?.canWorkChecklist != true ||
            task?.canComplete != true) {
          throw const AppApiException(
              message:
                  'Công việc chưa thể hoàn thành. Hãy bổ sung ảnh minh chứng nếu bắt buộc.');
        }
        await actions.completeTask(id);
      });
  Future<ShiftActionResult> skipTask(String id, String reason) =>
      _run('task:$id', () async {
        if (reason.trim().length < 3) {
          throw const AppApiException(
              message: 'Vui lòng ghi rõ lý do bỏ qua công việc.');
        }
        if (actions.snapshot?.canWorkChecklist != true) {
          throw const AppApiException(
              message: 'Ca hiện không cho phép sửa checklist.');
        }
        await actions.skipTask(id, reason.trim());
      });
  Future<ShiftActionResult> uploadTaskPhoto(String id, XFile image) =>
      _run('task:$id', () async {
        final task = actions.snapshot?.tasks.where((t) => t.id == id).firstOrNull;
        if (actions.snapshot?.canWorkChecklist != true ||
            task?.canUploadEvidence != true) {
          throw const AppApiException(
              message: 'Công việc hiện không cho phép thêm minh chứng.');
        }
        await actions.uploadTaskPhoto(id, image);
      });
  Future<ShiftActionResult> createTask(String name, String description) =>
      _run('create', () async {
        if (name.trim().length < 3) {
          throw const AppApiException(
              message: 'Tên công việc phải ít nhất 3 ký tự.');
        }
        if (actions.snapshot?.canWorkChecklist != true ||
            actions.snapshot?.allowAdHocTasks != true) {
          throw const AppApiException(
              message: 'Ca hiện không cho phép thêm công việc.');
        }
        await actions.createTask(name.trim(), description.trim());
      });
  Future<ShiftActionResult> checkout() => _run('checkout', () async {
        final booking = actions.snapshot;
        if (booking == null ||
            !ShiftActiveRules.canCheckout(
                booking.status, booking.tasks.map((t) => t.status))) {
          throw const AppApiException(
              message:
                  'Hoàn thành hoặc ghi lý do bỏ qua các công việc trước khi checkout.');
        }
        final generation = _generation;
        await actions.addNote(state.note);
        if (!_current(generation)) return;
        await actions.checkout();
        if (_current(generation)) reconcile(actions.snapshot);
      });
  Future<ShiftActionResult> reportIncident(String note) =>
      _run('incident', () async {
        final generation = _generation;
        await actions.raiseSos();
        if (_current(generation)) await actions.addNote(note);
      });
  Future<ShiftActionResult> _run(String key, Future<void> Function() action) async {
    if (!mounted || state.busy.contains(key)) return const ShiftActionIgnored();
    final generation = _generation;
    state = state.copyWith(busy: {...state.busy, key});
    try {
      await action();
      return _current(generation)
          ? const ShiftActionSuccess()
          : const ShiftActionIgnored();
    } catch (e) {
      if (!_current(generation)) return const ShiftActionIgnored();
      return ShiftActionFailure(e is AppApiException
          ? e.message
          : e is LocationUnavailableException
              ? e.message
              : 'Chưa hoàn tất thao tác. Vui lòng thử lại.');
    } finally {
      if (_current(generation)) {
        state = state.copyWith(busy: {...state.busy}..remove(key));
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
