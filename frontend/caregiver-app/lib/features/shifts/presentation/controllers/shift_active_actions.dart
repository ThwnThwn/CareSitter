import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

abstract interface class ShiftActiveActions {
  ShiftModel? get snapshot;
  Future<void> loadTasks();
  Future<String> uploadSelfie(XFile image);
  Future<void> checkIn();
  Future<void> completeTask(String id);
  Future<void> skipTask(String id, String reason);
  Future<void> uploadTaskPhoto(String id, XFile image);
  Future<void> createTask(String name, String description);
  Future<void> addNote(String note);
  Future<void> checkout();
  Future<void> raiseSos();
}
