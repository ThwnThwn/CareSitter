class NutritionProfileItem {
  const NutritionProfileItem({
    required this.id,
    required this.name,
    required this.relationshipLabel,
    required this.ageLabel,
    required this.avatarInitial,
    required this.supportingText,
    this.avatarPath,
    this.age,
    this.gender,
  });

  final String id;
  final String name;
  final String relationshipLabel;
  final String ageLabel;
  final String avatarInitial;
  final String supportingText;
  final String? avatarPath;
  final int? age;
  final String? gender;
}
