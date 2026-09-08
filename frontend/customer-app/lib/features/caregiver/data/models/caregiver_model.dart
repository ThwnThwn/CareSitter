/// Model ánh xạ response từ GET /api/v1/caregivers
class CaregiverModel {
  final String id;
  final String userId;
  final String? fullName;
  final String? bio;
  final int? yearsOfExperience;
  final int? hourlyRateExpected;
  final double ratingAvg;
  final int ratingCount;
  final String availabilityStatus; // ONLINE | BUSY | OFFLINE
  final List<String> skills;
  final String? serviceCity;
  final String? serviceDistrict;

  const CaregiverModel({
    required this.id,
    required this.userId,
    this.fullName,
    this.bio,
    this.yearsOfExperience,
    this.hourlyRateExpected,
    required this.ratingAvg,
    required this.ratingCount,
    required this.availabilityStatus,
    required this.skills,
    this.serviceCity,
    this.serviceDistrict,
  });

  String get displayName => fullName ?? 'Người chăm sóc';
  String get initials {
    final parts = displayName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  bool get isOnline => availabilityStatus == 'ONLINE';
  String get location => [serviceDistrict, serviceCity]
      .where((s) => s != null && s.isNotEmpty)
      .join(', ');

  factory CaregiverModel.fromJson(Map<String, dynamic> json) => CaregiverModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        userId: (json['userId'] ?? json['UserId'])?.toString() ?? '',
        fullName: json['fullName'] as String? ?? json['FullName'] as String?,
        bio: json['bio'] as String? ?? json['Bio'] as String?,
        yearsOfExperience: json['yearsOfExperience'] as int? ?? json['YearsOfExperience'] as int?,
        hourlyRateExpected: json['hourlyRateExpected'] as int? ?? json['HourlyRateExpected'] as int?,
        ratingAvg: ((json['ratingAvg'] ?? json['RatingAvg']) as num?)?.toDouble() ?? 0.0,
        ratingCount: json['ratingCount'] as int? ?? json['RatingCount'] as int? ?? 0,
        availabilityStatus:
            (json['availabilityStatus'] ?? json['AvailabilityStatus']) as String? ?? 'OFFLINE',
        skills: _parseSkills(json['skills'] ?? json['Skills']),
        serviceCity: json['serviceCity'] as String? ?? json['ServiceCity'] as String?,
        serviceDistrict: json['serviceDistrict'] as String? ?? json['ServiceDistrict'] as String?,
      );

  static List<String> _parseSkills(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }
}
