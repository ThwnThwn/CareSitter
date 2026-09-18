class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    String read(String camelCase, String pascalCase) =>
        (json[camelCase] ?? json[pascalCase])?.toString().trim() ?? '';

    return EmergencyContact(
      name: read('name', 'Name'),
      phone: read('phone', 'Phone'),
      relationship: read('relationship', 'Relationship'),
    );
  }
}

class BeneficiaryModel {
  final String id;
  final String name;
  final int age;
  final String relation;
  final String avatarInitial;
  final String condition;
  final String careLevel;
  final String notes;
  final String address;
  final String? defaultAddressId;
  final List<EmergencyContact> emergencyContacts;
  final String? avatarPath;

  const BeneficiaryModel({
    required this.id,
    required this.name,
    required this.age,
    required this.relation,
    required this.avatarInitial,
    required this.condition,
    required this.careLevel,
    required this.notes,
    required this.address,
    this.defaultAddressId,
    this.emergencyContacts = const [],
    this.avatarPath,
  });

  BeneficiaryModel copyWith({
    String? name,
    int? age,
    String? relation,
    String? avatarInitial,
    String? condition,
    String? careLevel,
    String? notes,
    String? address,
    String? defaultAddressId,
    List<EmergencyContact>? emergencyContacts,
    String? avatarPath,
  }) {
    return BeneficiaryModel(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      relation: relation ?? this.relation,
      avatarInitial: avatarInitial ?? this.avatarInitial,
      condition: condition ?? this.condition,
      careLevel: careLevel ?? this.careLevel,
      notes: notes ?? this.notes,
      address: address ?? this.address,
      defaultAddressId: defaultAddressId ?? this.defaultAddressId,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}
