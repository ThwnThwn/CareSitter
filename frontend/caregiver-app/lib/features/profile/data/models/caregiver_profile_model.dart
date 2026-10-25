import 'dart:convert';

/// Model hồ sơ Caregiver — map trực tiếp với API response từ
/// GET /api/v1/caregivers/me/profile
class CaregiverProfileModel {
  final String id;
  final String userId;
  final String? fullName;
  final String? bio;
  final int? yearsOfExperience;

  final double ratingAvg;
  final int ratingCount;

  /// DRAFT | PENDING | APPROVED | REJECTED | SUSPENDED
  final String kycStatus;

  /// ONLINE | OFFLINE | BUSY
  final String availabilityStatus;
  final List<String> skills;
  final String? serviceCity;
  final String? serviceDistrict;
  final String? gender;
  final String? dateOfBirth;

  /// URL ảnh đại diện từ Cloudinary (nullable)
  final String? avatarUrl;
  final String? cccdFrontUrl;
  final String? cccdBackUrl;
  final List<String> certificateUrls;
  final String? cccdFrontMediaId;
  final String? cccdBackMediaId;
  final List<String> certificateMediaIds;
  final bool requiresSecureResubmission;

  const CaregiverProfileModel({
    required this.id,
    required this.userId,
    this.fullName,
    this.bio,
    this.yearsOfExperience,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.kycStatus = 'DRAFT',
    this.availabilityStatus = 'OFFLINE',
    this.skills = const [],
    this.serviceCity,
    this.serviceDistrict,
    this.gender,
    this.dateOfBirth,
    this.avatarUrl,
    this.cccdFrontUrl,
    this.cccdBackUrl,
    this.certificateUrls = const [],
    this.cccdFrontMediaId,
    this.cccdBackMediaId,
    this.certificateMediaIds = const [],
    this.requiresSecureResubmission = false,
  });

  bool get isOnline => availabilityStatus == 'ONLINE';
  bool get isApproved => kycStatus == 'APPROVED';
  DateTime? get parsedDateOfBirth =>
      dateOfBirth == null ? null : DateTime.tryParse(dateOfBirth!);

  String get displayName =>
      fullName?.isNotEmpty == true ? fullName! : 'Caregiver';

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return displayName
          .substring(0, displayName.length < 2 ? displayName.length : 2)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get experienceText => yearsOfExperience == null
      ? 'Chưa cập nhật'
      : '$yearsOfExperience năm kinh nghiệm';

  String get locationText {
    final parts = [serviceDistrict, serviceCity]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Chưa cập nhật' : parts.join(', ');
  }

  // ── Compatibility Getters ──
  String get name => displayName;
  double get rating => ratingAvg;
  int get totalReviews => ratingCount;
  bool get isAvailable => isOnline;
  String get location => locationText;
  String get avatarInitial => initials;
  String get experience => experienceText;

  factory CaregiverProfileModel.fromJson(Map<String, dynamic> json) {
    return CaregiverProfileModel(
      id: _str(json['id'] ?? json['Id']) ?? '',
      userId: _str(json['userId'] ?? json['UserId']) ?? '',
      fullName: _str(json['fullName'] ?? json['FullName']),
      bio: _str(json['bio'] ?? json['Bio']),
      yearsOfExperience:
          _int(json['yearsOfExperience'] ?? json['YearsOfExperience']),
      ratingAvg: _dbl(json['ratingAvg'] ?? json['RatingAvg']),
      ratingCount: _int(json['ratingCount'] ?? json['RatingCount']) ?? 0,
      kycStatus: _str(json['kycStatus'] ?? json['KycStatus']) ?? 'DRAFT',
      availabilityStatus:
          _str(json['availabilityStatus'] ?? json['AvailabilityStatus']) ??
              'OFFLINE',
      skills: _parseSkills(json['skills'] ?? json['Skills']),
      serviceCity: _str(json['serviceCity'] ?? json['ServiceCity']),
      serviceDistrict: _str(json['serviceDistrict'] ?? json['ServiceDistrict']),
      gender: _str(json['gender'] ?? json['Gender']),
      dateOfBirth: _str(json['dateOfBirth'] ?? json['DateOfBirth']),
      avatarUrl: _str(json['avatarUrl'] ?? json['AvatarUrl']),
      // Never render legacy public KYC URLs, including responses from an old API.
      cccdFrontMediaId:
          _str(json['cccdFrontMediaId'] ?? json['CccdFrontMediaId']),
      cccdBackMediaId: _str(json['cccdBackMediaId'] ?? json['CccdBackMediaId']),
      certificateMediaIds: _parseStringList(
          json['certificateMediaIds'] ?? json['CertificateMediaIds']),
      requiresSecureResubmission: json['requiresSecureResubmission'] == true ||
          json['RequiresSecureResubmission'] == true ||
          _str(json['cccdFrontUrl'] ?? json['CccdFrontUrl']) != null ||
          _str(json['cccdBackUrl'] ?? json['CccdBackUrl']) != null,
    );
  }

  static CaregiverProfileModel empty() => const CaregiverProfileModel(
        id: '',
        userId: '',
      );

  static List<String> _parseSkills(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static double _dbl(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
