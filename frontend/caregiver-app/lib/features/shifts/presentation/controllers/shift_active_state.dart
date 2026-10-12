class ShiftActiveState {
  const ShiftActiveState(
      {this.step = 0,
      this.checkedIn = false,
      this.selfieUrl,
      this.startedAt,
      this.elapsed = Duration.zero,
      this.note = '',
      this.busy = const {},
      this.error});
  final int step;
  final bool checkedIn;
  final String? selfieUrl, error;
  final DateTime? startedAt;
  final Duration elapsed;
  final String note;
  final Set<String> busy;
  ShiftActiveState copyWith(
          {int? step,
          bool? checkedIn,
          String? selfieUrl,
          DateTime? startedAt,
          Duration? elapsed,
          String? note,
          Set<String>? busy,
          String? error}) =>
      ShiftActiveState(
          step: step ?? this.step,
          checkedIn: checkedIn ?? this.checkedIn,
          selfieUrl: selfieUrl ?? this.selfieUrl,
          startedAt: startedAt ?? this.startedAt,
          elapsed: elapsed ?? this.elapsed,
          note: note ?? this.note,
          busy: busy == null ? this.busy : Set.unmodifiable(busy),
          error: error);
}
