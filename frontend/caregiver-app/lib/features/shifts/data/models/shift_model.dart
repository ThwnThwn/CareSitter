import 'package:caregiver_app/features/shifts/data/models/care_task_model.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_status.dart';

export 'package:caregiver_app/features/shifts/data/models/care_task_model.dart';
export 'package:caregiver_app/features/shifts/data/models/shift_beneficiary_model.dart';
export 'package:caregiver_app/features/shifts/data/models/shift_status.dart';

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

  /// True nếu gói dịch vụ cho phép caregiver thêm task phát sinh
  final bool allowAdHocTasks;

  /// True nếu ca cần admin/customer review (có task bắt buộc bị bỏ qua)
  final bool needsReview;

  ShiftStatus get statusType => ShiftStatus.fromApi(status);

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
    this.allowAdHocTasks = false,
    this.needsReview = false,
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
    bool? allowAdHocTasks,
    bool? needsReview,
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
      allowAdHocTasks: allowAdHocTasks ?? this.allowAdHocTasks,
      needsReview: needsReview ?? this.needsReview,
    );
  }
}
