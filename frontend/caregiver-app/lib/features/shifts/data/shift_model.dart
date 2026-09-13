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

class CareTaskModel {
  final String id;
  final String title;
  final String? description;
  final bool isRequired;
  final bool requiresPhoto;
  final String status;
  final bool isCompleted;
  final List<String> photoUrls;

  const CareTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.isRequired = false,
    this.requiresPhoto = false,
    this.status = 'PENDING',
    this.isCompleted = false,
    this.photoUrls = const [],
  });

  bool get isSkipped => status.toUpperCase() == 'SKIPPED';
  bool get isResolved => isCompleted || isSkipped;

  factory CareTaskModel.fromApi(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase() ?? 'PENDING';
    return CareTaskModel(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? 'Nhiệm vụ chăm sóc',
      description: json['description']?.toString(),
      isRequired: json['isRequired'] as bool? ?? false,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      status: status,
      isCompleted: status == 'DONE',
      photoUrls: (json['photoUrls'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  CareTaskModel copyWith(
      {String? status, bool? isCompleted, List<String>? photoUrls}) {
    final nextStatus = status ?? this.status;
    return CareTaskModel(
      id: id,
      title: title,
      description: description,
      isRequired: isRequired,
      requiresPhoto: requiresPhoto,
      status: nextStatus,
      isCompleted: isCompleted ?? nextStatus.toUpperCase() == 'DONE',
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }
}

class ShiftModel {
  final String id;
  final String? beneficiaryId;
  final String beneficiaryName;
  final String? caregiverId;
  final String caregiverName;
  final String caregiverAvatar;
  final String? serviceId;
  final String serviceName;
  final String? serviceDescription;
  final String date;
  final String time;
  final String duration;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String status;
  final double totalPrice;
  final String address;
  final double? addressLatitude;
  final double? addressLongitude;
  final String? customerNote;
  final String? offerId;
  final DateTime? offerExpiresAt;
  final int? offerRank;
  final bool isSystemMatched;
  final String paymentLabel;
  final DateTime? consentAcceptedAt;
  final DateTime? actualStart;
  final DateTime? checkoutRequestedAt;
  final DateTime? completedAt;
  final bool isReviewed;
  final String? disputeReason;
  final List<CareTaskModel> tasks;
  final double platformRevenue;
  final double caregiverEarning;
  final int? beneficiaryAge;
  final String? beneficiaryRelationship;
  final String? beneficiaryCondition;
  final String? beneficiaryNotes;

  const ShiftModel({
    required this.id,
    this.beneficiaryId,
    required this.beneficiaryName,
    this.caregiverId,
    required this.caregiverName,
    required this.caregiverAvatar,
    this.serviceId,
    required this.serviceName,
    this.serviceDescription,
    required this.date,
    required this.time,
    required this.duration,
    this.scheduledStart,
    this.scheduledEnd,
    required this.status,
    required this.totalPrice,
    required this.address,
    this.addressLatitude,
    this.addressLongitude,
    this.customerNote,
    this.offerId,
    this.offerExpiresAt,
    this.offerRank,
    this.isSystemMatched = false,
    this.paymentLabel = 'Ví CareSitter',
    this.consentAcceptedAt,
    this.actualStart,
    this.checkoutRequestedAt,
    this.completedAt,
    this.isReviewed = false,
    this.disputeReason,
    this.tasks = const [],
    this.platformRevenue = 0,
    this.caregiverEarning = 0,
    this.beneficiaryAge,
    this.beneficiaryRelationship,
    this.beneficiaryCondition,
    this.beneficiaryNotes,
  });

  ShiftModel copyWith({
    String? status,
    DateTime? actualStart,
    DateTime? checkoutRequestedAt,
    DateTime? completedAt,
    bool? isReviewed,
    String? disputeReason,
    String? offerId,
    DateTime? offerExpiresAt,
    int? offerRank,
    List<CareTaskModel>? tasks,
    double? platformRevenue,
    double? caregiverEarning,
    int? beneficiaryAge,
    String? beneficiaryRelationship,
    String? beneficiaryCondition,
    String? beneficiaryNotes,
  }) {
    return ShiftModel(
      id: id,
      beneficiaryId: beneficiaryId,
      beneficiaryName: beneficiaryName,
      caregiverId: caregiverId,
      caregiverName: caregiverName,
      caregiverAvatar: caregiverAvatar,
      serviceId: serviceId,
      serviceName: serviceName,
      serviceDescription: serviceDescription,
      date: date,
      time: time,
      duration: duration,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: status ?? this.status,
      totalPrice: totalPrice,
      address: address,
      addressLatitude: addressLatitude,
      addressLongitude: addressLongitude,
      customerNote: customerNote,
      offerId: offerId ?? this.offerId,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      offerRank: offerRank ?? this.offerRank,
      isSystemMatched: isSystemMatched,
      paymentLabel: paymentLabel,
      consentAcceptedAt: consentAcceptedAt,
      actualStart: actualStart ?? this.actualStart,
      checkoutRequestedAt: checkoutRequestedAt ?? this.checkoutRequestedAt,
      completedAt: completedAt ?? this.completedAt,
      isReviewed: isReviewed ?? this.isReviewed,
      disputeReason: disputeReason ?? this.disputeReason,
      tasks: tasks ?? this.tasks,
      platformRevenue: platformRevenue ?? this.platformRevenue,
      caregiverEarning: caregiverEarning ?? this.caregiverEarning,
      beneficiaryAge: beneficiaryAge ?? this.beneficiaryAge,
      beneficiaryRelationship:
          beneficiaryRelationship ?? this.beneficiaryRelationship,
      beneficiaryCondition: beneficiaryCondition ?? this.beneficiaryCondition,
      beneficiaryNotes: beneficiaryNotes ?? this.beneficiaryNotes,
    );
  }
}
