import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_actions.dart';

ShiftModel booking(
        {String status = 'in_progress',
        List<CareTaskModel> tasks = const []}) =>
    ShiftModel(
        id: 'shift',
        beneficiaryName: 'An',
        caregiverName: 'Caregiver',
        caregiverAvatar: '',
        serviceName: 'Chăm sóc',
        status: status,
        totalPrice: 200000,
        address: '',
        actualStart: DateTime(2026, 10, 12, 8),
        tasks: tasks);

class FakeShiftActiveActions implements ShiftActiveActions {
  @override
  ShiftModel? snapshot = booking();
  int checkouts = 0, notes = 0, completed = 0, uploads = 0;
  bool failNote = false;
  Completer<void>? pendingTask;
  Completer<String>? pendingSelfie;
  @override
  Future<void> loadTasks() async {}
  @override
  Future<String> uploadSelfie(XFile image) async =>
      pendingSelfie == null ? 'saved-selfie' : await pendingSelfie!.future;
  @override
  Future<void> checkIn() async {
    snapshot = snapshot!.copyWith(status: 'in_progress');
  }

  @override
  Future<void> completeTask(String id) async {
    completed++;
    await pendingTask?.future;
  }

  @override
  Future<void> skipTask(String id, String reason) async {}
  @override
  Future<void> uploadTaskPhoto(String id, XFile image) async {
    uploads++;
  }

  @override
  Future<void> createTask(String name, String description) async {}
  @override
  Future<void> addNote(String note) async {
    notes++;
    if (failNote) throw const AppApiException(message: 'Chưa lưu được ghi chú');
  }

  @override
  Future<void> checkout() async {
    checkouts++;
    snapshot = snapshot!.copyWith(
        status: 'checkout_pending_review',
        checkoutRequestedAt: DateTime(2026, 10, 12, 10));
  }

  @override
  Future<void> raiseSos() async {}
}
