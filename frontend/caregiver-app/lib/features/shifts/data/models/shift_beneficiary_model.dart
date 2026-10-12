class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });
}

class ShiftBeneficiaryModel {
  final String id;
  final String name;
  final int age;
  final String relation;
  final String avatarInitial;
  final String condition;
  final String careLevel;
  final String notes;
  final String address;
  final List<EmergencyContact> emergencyContacts;

  const ShiftBeneficiaryModel({
    required this.id,
    required this.name,
    required this.age,
    required this.relation,
    required this.avatarInitial,
    required this.condition,
    required this.careLevel,
    required this.notes,
    this.address = '',
    this.emergencyContacts = const [],
  });
}
