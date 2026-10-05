/// Shared REST/SignalR GPS payload. Invalid fixes are rejected, never replaced
/// with coordinates (0, 0) or a fabricated current timestamp.
class GpsUpdate {
  final String bookingId;
  final String caregiverId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;
  final DateTime? receivedAt;
  final int version;
  final int bookingVersion;
  final String? sessionId;

  const GpsUpdate(
      {required this.bookingId,
      required this.latitude,
      required this.longitude,
      required this.recordedAt,
      this.caregiverId = '',
      this.accuracyMeters,
      this.speed,
      this.heading,
      this.receivedAt,
      this.version = 0,
      this.bookingVersion = 0,
      this.sessionId});

  factory GpsUpdate.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    final captured = DateTime.tryParse(
        (json['capturedAt'] ?? json['recordedAt'])?.toString() ?? '');
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        captured == null ||
        version <= 0 ||
        json['bookingId'] is! String ||
        (json['bookingId'] as String).isEmpty) {
      throw const FormatException('Invalid live GPS fix');
    }
    double? optional(String key, {double? max}) {
      final value = (json[key] as num?)?.toDouble();
      return value != null &&
              value.isFinite &&
              value >= 0 &&
              (max == null || value < max)
          ? value
          : null;
    }

    return GpsUpdate(
        bookingId: json['bookingId'] as String,
        caregiverId: json['caregiverId']?.toString() ?? '',
        latitude: lat,
        longitude: lng,
        recordedAt: captured,
        version: version,
        bookingVersion: (json['bookingVersion'] as num?)?.toInt() ?? 0,
        receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
        sessionId: json['sessionId']?.toString(),
        accuracyMeters: optional('accuracyMeters'),
        speed: optional('speed'),
        heading: optional('heading', max: 360));
  }
}

/// Orders snapshots and push events with the same server version watermark.
class LiveGpsAccumulator {
  int _version = 0;
  GpsUpdate? latest;
  int get version => _version;

  bool accept(GpsUpdate fix,
      {required String bookingId,
      required String? caregiverId,
      required bool enRoute}) {
    if (!enRoute ||
        fix.bookingId != bookingId ||
        fix.caregiverId != caregiverId ||
        fix.version <= _version) {
      return false;
    }
    _version = fix.version;
    latest = fix;
    return true;
  }

  // Preserve the watermark so a delayed request cannot restore a cleared fix.
  void clear() => latest = null;
}
