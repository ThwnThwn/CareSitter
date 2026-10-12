import '../../data/models/shift_model.dart';
import '../../domain/shift_action_rules.dart';

extension ShiftActionPolicy on ShiftModel {
  bool get canAccept => ShiftActionRules.canAccept(statusType.apiValue);
  bool get canStartEnRoute => ShiftActionRules.canStartEnRoute(statusType.apiValue);
  bool get canCheckIn => ShiftActionRules.canCheckIn(statusType.apiValue);
  bool get canWorkChecklist =>
      ShiftActionRules.canWorkChecklist(statusType.apiValue);
  bool get canRequestCheckout => canWorkChecklist;
}

extension CareTaskActionPolicy on CareTaskModel {
  bool get isTerminal =>
      ShiftActionRules.taskTerminal(completed: isCompleted, status: status);
  bool get canUploadEvidence => !isTerminal;
  bool get canComplete => ShiftActionRules.canCompleteTask(
      completed: isCompleted,
      status: status,
      requiresPhoto: requiresPhoto,
      hasPhoto: photoUrls.isNotEmpty);
}
