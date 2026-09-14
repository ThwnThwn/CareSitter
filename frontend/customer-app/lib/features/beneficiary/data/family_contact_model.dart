class FamilyContactModel {
  const FamilyContactModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.note,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String? note;

  factory FamilyContactModel.fromJson(Map<String, dynamic> json) =>
      FamilyContactModel(
        id: (json['id'] ?? json['Id']).toString(),
        fullName: (json['fullName'] ?? json['FullName'] ?? '').toString(),
        phoneNumber:
            (json['phoneNumber'] ?? json['PhoneNumber'] ?? '').toString(),
        note: (json['note'] ?? json['Note'])?.toString(),
      );
}
