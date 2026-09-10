class CaregiverProfileModel {
  final String id;
  final String name;
  final String avatarInitial;
  final double rating;
  final int totalReviews;
  final int completedShifts;
  final List<String> skills;
  final String experience;
  final String location;
  final double hourlyRate;
  final bool isAvailable;
  final String certifications;

  const CaregiverProfileModel({
    required this.id,
    required this.name,
    required this.avatarInitial,
    required this.rating,
    required this.totalReviews,
    required this.completedShifts,
    required this.skills,
    required this.experience,
    required this.location,
    required this.hourlyRate,
    required this.isAvailable,
    required this.certifications,
  });
}
