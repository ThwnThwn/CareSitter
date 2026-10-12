import 'care_task_model.dart';
import 'booking_status_codec.dart';
export 'care_task_model.dart';
export 'gps_track_model.dart';
export 'booking_list_response.dart';

class BookingModel {
  final String id;
  final String beneficiaryId;
  final String? caregiverId;
  final String addressId;
  final String serviceTypeId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final DateTime? checkoutPendingReviewAt;
  final String? checkoutSource;
  final String
      status; // pending | confirmed | caregiver_en_route | in_progress | ...
  final int escrowAmount;
  final int? customerPayableAmount;
  final int platformFeeAmount;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Fields enriched từ related APIs (people, catalog)
  final String? caregiverName;
  final String? caregiverAvatar;
  final String? beneficiaryName;
  final String? beneficiaryNotes;
  final String? addressText;
  final double? addressLatitude;
  final double? addressLongitude;
  final String? serviceName;

  /// Version tăng mỗi khi booking được mutation trên server.
  /// Dùng khi merge delta để bỏ qua update cũ / đến đảo thứ tự.
  final int syncVersion;

  const BookingModel({
    required this.id,
    required this.beneficiaryId,
    this.caregiverId,
    required this.addressId,
    required this.serviceTypeId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.checkoutPendingReviewAt,
    this.checkoutSource,
    required this.status,
    required this.escrowAmount,
    this.customerPayableAmount,
    required this.platformFeeAmount,
    this.cancelledAt,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
    this.caregiverName,
    this.caregiverAvatar,
    this.beneficiaryName,
    this.beneficiaryNotes,
    this.addressText,
    this.addressLatitude,
    this.addressLongitude,
    this.serviceName,
    this.isReviewed = false,
    this.tasks = const [],
    this.syncVersion = 0,
    this.allowAdHocTasks = false,
    this.needsReview = false,
  });

  final bool isReviewed;
  final List<CareTaskModel> tasks;

  /// True khi gói cho phép caregiver thêm task phát sinh
  final bool allowAdHocTasks;

  /// True khi ca có task bắt buộc bỏ qua — cần admin/customer review
  final bool needsReview;

  // ── copyWith ─────────────────────────────────────────────────────────────

  BookingModel copyWith({
    String? status,
    String? caregiverId,
    String? caregiverName,
    String? caregiverAvatar,
    String? beneficiaryNotes,
    DateTime? actualStart,
    DateTime? actualEnd,
    DateTime? checkoutPendingReviewAt,
    String? checkoutSource,
    DateTime? cancelledAt,
    String? cancelReason,
    DateTime? updatedAt,
    bool? isReviewed,
    List<CareTaskModel>? tasks,
    int? syncVersion,
    bool? allowAdHocTasks,
    bool? needsReview,
  }) {
    return BookingModel(
      id: id,
      beneficiaryId: beneficiaryId,
      caregiverId: caregiverId ?? this.caregiverId,
      addressId: addressId,
      serviceTypeId: serviceTypeId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      checkoutPendingReviewAt:
          checkoutPendingReviewAt ?? this.checkoutPendingReviewAt,
      checkoutSource: checkoutSource ?? this.checkoutSource,
      status: status ?? this.status,
      escrowAmount: escrowAmount,
      customerPayableAmount: customerPayableAmount,
      platformFeeAmount: platformFeeAmount,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverAvatar: caregiverAvatar ?? this.caregiverAvatar,
      beneficiaryName: beneficiaryName,
      beneficiaryNotes: beneficiaryNotes ?? this.beneficiaryNotes,
      addressText: addressText,
      addressLatitude: addressLatitude,
      addressLongitude: addressLongitude,
      serviceName: serviceName,
      isReviewed: isReviewed ?? this.isReviewed,
      tasks: tasks ?? this.tasks,
      syncVersion: syncVersion ?? this.syncVersion,
      allowAdHocTasks: allowAdHocTasks ?? this.allowAdHocTasks,
      needsReview: needsReview ?? this.needsReview,
    );
  }

  // ── fromJson ─────────────────────────────────────────────────────────────

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final scheduledStart =
        _parseNullableApiDateTime(json['scheduledStart']) ?? now;
    final scheduledEnd = _parseNullableApiDateTime(json['scheduledEnd']) ??
        scheduledStart.add(const Duration(hours: 1));

    return BookingModel(
      id: _string(json['id']) ?? '',
      beneficiaryId: _string(json['beneficiaryId']) ?? '',
      caregiverId: _string(json['caregiverId']),
      addressId: _string(json['addressId']) ?? '',
      serviceTypeId: _string(json['serviceTypeId']) ?? '',
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStart: _parseNullableApiDateTime(json['actualStart']),
      actualEnd: _parseNullableApiDateTime(json['actualEnd']),
      checkoutPendingReviewAt:
          _parseNullableApiDateTime(json['checkoutPendingReviewAt']),
      checkoutSource: _string(json['checkoutSource']),
      status: normalizeBookingStatus(_string(json['status']) ?? 'draft'),
      escrowAmount: _int(json['escrowAmount']),
      customerPayableAmount: json['customerPayableAmount'] == null
          ? null
          : _int(json['customerPayableAmount']),
      platformFeeAmount: _int(json['platformFeeAmount']),
      cancelledAt: _parseNullableApiDateTime(json['cancelledAt']),
      cancelReason: _string(json['cancelReason']),
      createdAt: _parseNullableApiDateTime(json['createdAt']) ?? now,
      updatedAt: _parseNullableApiDateTime(json['updatedAt']) ?? now,
      caregiverName: _string(json['caregiverName']),
      caregiverAvatar: _string(json['caregiverAvatar']),
      beneficiaryName: _string(json['beneficiaryName']),
      beneficiaryNotes:
          _string(json['beneficiaryNotes']) ?? _string(json['note']),
      addressText: _string(json['addressText']),
      addressLatitude: _double(json['addressLatitude']),
      addressLongitude: _double(json['addressLongitude']),
      serviceName: _string(json['serviceName']),
      syncVersion: _int(json['syncVersion']),
      allowAdHocTasks: json['allowAdHocTasks'] as bool? ?? false,
      needsReview: json['needsReview'] as bool? ?? false,
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CareTaskModel.fromApi)
          .toList(),
    );
  }

  static DateTime _parseApiDateTime(String value) =>
      DateTime.tryParse(value)?.toLocal() ?? DateTime.now();

  static DateTime? _parseNullableApiDateTime(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return _parseApiDateTime(text);
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
