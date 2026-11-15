import '../../../caregiver/data/models/caregiver_model.dart';

class CaregiverSuggestionModel {
  const CaregiverSuggestionModel(this.caregiver);
  final CaregiverModel caregiver;
  factory CaregiverSuggestionModel.fromJson(Map<String, dynamic> json) =>
      CaregiverSuggestionModel(CaregiverModel(
        id: json['caregiverId'] as String,
        userId: '',
        fullName: json['displayName'] as String?,
        yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
        ratingAvg: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        availabilityStatus: json['availabilityStatus'] as String? ?? 'OFFLINE',
        skills: const [],
        distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
        matchReasons: (json['matchReasons'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      ));
}
