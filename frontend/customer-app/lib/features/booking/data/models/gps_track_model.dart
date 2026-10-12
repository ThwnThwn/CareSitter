import 'package:latlong2/latlong.dart';

class GpsTrackModel {
  final String id;
  final String bookingId;
  final String caregiverId;
  final int version;
  final int bookingVersion;
  final DateTime? receivedAt;
  final String? sessionId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  const GpsTrackModel({
    required this.id,
    required this.bookingId,
    required this.caregiverId,
    this.version = 0,
    this.bookingVersion = 0,
    this.receivedAt,
    this.sessionId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  factory GpsTrackModel.fromJson(Map<String, dynamic> json) => GpsTrackModel(
        id: _string(json['id']) ?? '',
        bookingId: _string(json['bookingId']) ?? '',
        caregiverId: _string(json['caregiverId']) ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
        bookingVersion: (json['bookingVersion'] as num?)?.toInt() ?? 0,
        receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
        sessionId: _string(json['sessionId']),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        accuracyMeters: _nullableDouble(json['accuracyMeters']),
        speed: _nullableDouble(json['speed']),
        heading: _nullableDouble(json['heading']),
        recordedAt: DateTime.parse(
            (json['capturedAt'] ?? json['recordedAt']).toString()),
      );

  LatLng get latLng => LatLng(latitude, longitude);

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
