import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_actions.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class RiverpodShiftActiveActions implements ShiftActiveActions {
  const RiverpodShiftActiveActions(this.ref, this.id);
  final Ref ref;
  final String id;
  ShiftListController get _store => ref.read(shiftsProvider.notifier);
  @override
  ShiftModel? get snapshot =>
      ref.read(shiftsProvider).where((b) => b.id == id).firstOrNull;
  @override
  Future<void> loadTasks() => _store.loadTasks(id);
  @override
  Future<String> uploadSelfie(XFile image) =>
      _store.uploadCheckInSelfie(id, image);
  @override
  Future<void> checkIn() => _store.checkIn(id);
  @override
  Future<void> completeTask(String taskId) => _store.completeTask(id, taskId);
  @override
  Future<void> skipTask(String taskId, String reason) =>
      _store.skipTask(id, taskId, reason);
  @override
  Future<void> uploadTaskPhoto(String taskId, XFile image) async {
    await _store.uploadTaskPhoto(id, taskId, image);
  }

  @override
  Future<void> createTask(String name, String description) =>
      _store.createTask(id, name, description: description);
  @override
  Future<void> addNote(String note) => _store.addTimelineNote(id, note);
  @override
  Future<void> checkout() => _store.checkOut(id);
  @override
  Future<void> raiseSos() => _store.raiseSos(id);
}
