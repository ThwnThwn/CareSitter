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
  final String title;
  final bool isCompleted;

  const CareTaskModel({
    required this.title,
    this.isCompleted = false,
  });

  CareTaskModel copyWith({bool? isCompleted}) {
    return CareTaskModel(
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
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
  final String date;
  final String time;
  final String duration;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String status;
  final double totalPrice;
  final String address;
  final String? customerNote;
  final bool isSystemMatched;
  final String paymentLabel;
  final DateTime? consentAcceptedAt;
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
    required this.date,
    required this.time,
    required this.duration,
    this.scheduledStart,
    this.scheduledEnd,
    required this.status,
    required this.totalPrice,
    required this.address,
    this.customerNote,
    this.isSystemMatched = false,
    this.paymentLabel = 'Ví CareSitter',
    this.consentAcceptedAt,
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
    DateTime? checkoutRequestedAt,
    DateTime? completedAt,
    bool? isReviewed,
    String? disputeReason,
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
      date: date,
      time: time,
      duration: duration,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: status ?? this.status,
      totalPrice: totalPrice,
      address: address,
      customerNote: customerNote,
      isSystemMatched: isSystemMatched,
      paymentLabel: paymentLabel,
      consentAcceptedAt: consentAcceptedAt,
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
