enum ReportPhase {
  loading,
  idle,
  generating,
  uploading,
  processing,
  previewing
}

class ReportState {
  const ReportState(
      {this.phase = ReportPhase.loading,
      this.hasDocument = false,
      this.progress = 0,
      this.reportId,
      this.error,
      this.uncertain = false,
      this.page = 1});
  final ReportPhase phase;
  final bool hasDocument, uncertain;
  final double progress;
  final String? reportId, error;
  final int page;
  bool get busy => phase != ReportPhase.idle;
  ReportState copyWith(
          {ReportPhase? phase,
          bool? hasDocument,
          bool? uncertain,
          double? progress,
          String? reportId,
          String? error,
          int? page}) =>
      ReportState(
          phase: phase ?? this.phase,
          hasDocument: hasDocument ?? this.hasDocument,
          uncertain: uncertain ?? this.uncertain,
          progress: progress ?? this.progress,
          reportId: reportId ?? this.reportId,
          error: error,
          page: page ?? this.page);
}
