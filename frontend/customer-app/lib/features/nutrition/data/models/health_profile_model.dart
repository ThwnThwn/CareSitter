import 'dart:collection';

/// Snapshot People; giữ trường chưa biết để không làm mất hồ sơ đã lưu.
class HealthProfileModel extends UnmodifiableMapView<String, dynamic> {
  HealthProfileModel.fromJson(Map<String, dynamic> json) : super(Map.of(json));
  int get revision => (this['revision'] as num?)?.toInt() ?? 0;
  String get allergyStatus => this['allergyStatus']?.toString() ?? 'unknown';
  Map<String, dynamic> toJson() => Map.of(this);
}
