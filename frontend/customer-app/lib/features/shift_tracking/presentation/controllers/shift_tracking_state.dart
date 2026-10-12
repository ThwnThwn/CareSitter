class ShiftTrackingState {
  const ShiftTrackingState({
    this.latitude,
    this.longitude,
    this.heading,
    this.recordedAt,
    this.label = 'Đang chờ vị trí',
  });
  final double? latitude;
  final double? longitude;
  final double? heading;
  final DateTime? recordedAt;
  final String label;
  bool get stale =>
      recordedAt != null &&
      DateTime.now().difference(recordedAt!).inSeconds > 60;
}
