import 'dart:convert';

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
  static const _unchanged = Object();

  int? ageAt(DateTime today) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    var years = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      years--;
    }
    return years;
  }

  int? get age => ageAt(DateTime.now());
  String get ageLabel => age == null ? 'Chưa có ngày sinh' : '$age tuổi';
  String get conditionLabel =>
      condition.isEmpty ? 'Chưa có ghi chú' : condition;
  String get careLevelLabel => careLevel.isEmpty ? 'Chưa cập nhật' : careLevel;

  // Chỉ gửi trường form thực sự sửa; dữ liệu sức khỏe được giữ tại server.
  Map<String, dynamic> toProfileRequest(
      {BeneficiaryModel? previous, String? avatarUrl}) {
    final fields = <String, dynamic>{
      'FullName': name,
      'DefaultAddressId': defaultAddressId,
      'DateOfBirth': dateOfBirth?.toIso8601String().split('T').first,
      'Gender': gender,
      'RelationshipToCustomer': relation,
      'GeneralNote': condition,
      'CareInstructions': notes,
      'CareLevel': careLevel.isEmpty ? null : careLevel,
      'EmergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
      'AvatarUrl': avatarUrl,
    };
    if (previous != null) {
      final old = previous.toProfileRequest(avatarUrl: previous.avatarPath);
      fields.removeWhere((key, value) =>
          key != 'FullName' &&
          key != 'DefaultAddressId' &&
          jsonEncode(value) == jsonEncode(old[key]));
    }
    return fields;
  }

  final String id;
  final bool isSelf;
  final String name;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? mobilityNote;
  final Object? healthHistory;
  final Object? allergies;
  final Object? chronicConditions;
  final Object? medications;
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
    this.isSelf = false,
    required this.name,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.mobilityNote,
    this.healthHistory,
    this.allergies,
    this.chronicConditions,
    this.medications,
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
    Object? dateOfBirth = _unchanged,
    Object? gender = _unchanged,
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
      isSelf: isSelf,
      name: name ?? this.name,
      dateOfBirth: identical(dateOfBirth, _unchanged)
          ? this.dateOfBirth
          : dateOfBirth as DateTime?,
      gender: identical(gender, _unchanged) ? this.gender : gender as String?,
      phone: phone,
      mobilityNote: mobilityNote,
      healthHistory: healthHistory,
      allergies: allergies,
      chronicConditions: chronicConditions,
      medications: medications,
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

  factory BeneficiaryModel.fromBackend(
    Map<String, dynamic> map, {
    Map<String, String> addressesById = const {},
  }) {
    final id = (map['id'] ?? map['Id'])?.toString() ?? '';
    final fullName =
        (map['fullName'] ?? map['FullName']) as String? ?? 'Người thân';
    final dobStr = (map['dateOfBirth'] ?? map['DateOfBirth']) as String?;
    final dateOfBirth = dobStr == null ? null : DateTime.tryParse(dobStr);
    final relation = (map['relationshipToCustomer'] ??
            map['RelationshipToCustomer']) as String? ??
        'Người thân';
    final mobilityNote =
        (map['mobilityNote'] ?? map['MobilityNote']) as String?;
    final generalNote = (map['generalNote'] ?? map['GeneralNote']) as String?;
    final careInstructions =
        (map['careInstructions'] ?? map['CareInstructions']) as String? ?? '';
    final defaultAddressId =
        (map['defaultAddressId'] ?? map['DefaultAddressId'])?.toString();
    final address =
        defaultAddressId == null ? '' : addressesById[defaultAddressId] ?? '';
    final careLevel = (map['careLevel'] ?? map['CareLevel'])?.toString().trim();
    final avatarUrl = (map['avatarUrl'] ?? map['AvatarUrl'])?.toString().trim();
    final emergencyContacts = _readEmergencyContacts(
      map['emergencyContacts'] ?? map['EmergencyContacts'],
    );

    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(3)
        .join();

    return BeneficiaryModel(
      id: id,
      isSelf: (map['isSelf'] ?? map['IsSelf']) == true,
      name: fullName,
      dateOfBirth: dateOfBirth,
      gender: (map['gender'] ?? map['Gender']) as String?,
      phone: (map['phone'] ?? map['Phone']) as String?,
      mobilityNote: mobilityNote,
      healthHistory: map['healthHistory'] ?? map['HealthHistory'],
      allergies: map['allergies'] ?? map['Allergies'],
      chronicConditions: map['chronicConditions'] ?? map['ChronicConditions'],
      medications: map['medications'] ?? map['Medications'],
      relation: relation,
      avatarInitial: initials.isNotEmpty ? initials : 'B',
      condition: generalNote ?? '',
      careLevel: careLevel ?? '',
      notes: careInstructions,
      address: address,
      defaultAddressId: defaultAddressId,
      emergencyContacts: emergencyContacts,
      avatarPath: avatarUrl == null || avatarUrl.isEmpty ? null : avatarUrl,
    );
  }

  static List<EmergencyContact> _readEmergencyContacts(Object? raw) {
    Object? value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => EmergencyContact.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .where((contact) => contact.name.isNotEmpty && contact.phone.isNotEmpty)
        .toList(growable: false);
  }
}
