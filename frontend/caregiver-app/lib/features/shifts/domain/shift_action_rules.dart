/// Local action gates mirror server states; the server still authorizes writes.
class ShiftActionRules {
  const ShiftActionRules._();
  static bool canAccept(String status) => status == 'open' || status == 'pending';
  static bool canStartEnRoute(String status) =>
      status == 'confirmed' || status == 'assigned';
  static bool canCheckIn(String status) => status == 'caregiver_en_route';
  static bool canWorkChecklist(String status) => status == 'in_progress';
  static bool taskTerminal({required bool completed, required String status}) =>
      completed || status.toUpperCase() == 'SKIPPED';
  static bool canCompleteTask(
          {required bool completed,
          required String status,
          required bool requiresPhoto,
          required bool hasPhoto}) =>
      !taskTerminal(completed: completed, status: status) &&
      (!requiresPhoto || hasPhoto);
}
