class CaregiverMatchRules {
  const CaregiverMatchRules._();
  static List<T> rankOnline<T>(List<T> items,
          {required bool Function(T) isOnline,
          required double Function(T) rating}) =>
      items.where(isOnline).toList()
        ..sort((a, b) => rating(b).compareTo(rating(a)));
}
