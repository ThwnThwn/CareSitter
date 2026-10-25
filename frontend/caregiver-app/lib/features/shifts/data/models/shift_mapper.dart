import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

ShiftModel mapShiftFromApi(Map<String, dynamic> json) {
  final id = json['id']?.toString() ?? '';
  final rawStatus = json['status']?.toString().toLowerCase() ?? 'pending';

  String mappedStatus = rawStatus;
  if (rawStatus == 'payment_confirmed' || rawStatus == 'confirmed') {
    mappedStatus = 'pending';
  } else if (rawStatus == 'caregiver_accepted' || rawStatus == 'assigned') {
    mappedStatus = 'confirmed';
  } else if (rawStatus == 'caregiver_en_route' || rawStatus == 'en_route') {
    mappedStatus = 'caregiver_en_route';
  } else if (rawStatus == 'in_progress') {
    mappedStatus = 'in_progress';
  } else if (rawStatus == 'checkout_pending_review') {
    mappedStatus = 'checkout_pending_review';
  } else if (rawStatus == 'completed') {
    mappedStatus = 'completed';
  } else if (rawStatus == 'cancelled') {
    mappedStatus = 'cancelled';
  } else if (rawStatus == 'pending_payment' || rawStatus == 'draft') {
    mappedStatus = rawStatus;
  }

  final escrow = (json['escrowAmount'] as num?)?.toDouble() ?? 0.0;
  final fee = (json['platformFeeAmount'] as num?)?.toDouble() ?? 0.0;
  // Dùng số tiền backend chốt; fallback chỉ để tương thích API cũ.
  final earning = (json['caregiverEarningAmount'] as num?)?.toDouble() ??
      (escrow > 0 ? (escrow - fee) : 0.0);

  DateTime? start;
  if (json['scheduledStart'] != null) {
    start = DateTime.tryParse(json['scheduledStart'].toString())?.toLocal();
  }
  DateTime? end;
  if (json['scheduledEnd'] != null) {
    end = DateTime.tryParse(json['scheduledEnd'].toString())?.toLocal();
  }

  DateTime? checkoutRequestedAt;
  if (json['checkoutPendingReviewAt'] != null) {
    checkoutRequestedAt =
        DateTime.tryParse(json['checkoutPendingReviewAt'].toString())
            ?.toLocal();
  } else if (json['actualEnd'] != null) {
    checkoutRequestedAt =
        DateTime.tryParse(json['actualEnd'].toString())?.toLocal();
  }

  DateTime? completedAt;
  if (json['updatedAt'] != null && mappedStatus == 'completed') {
    completedAt = DateTime.tryParse(json['updatedAt'].toString())?.toLocal();
  }

  final int? beneficiaryAge = (json['beneficiaryAge'] as num?)?.toInt();
  final String? beneficiaryRelationship =
      json['beneficiaryRelationship']?.toString();
  final String? beneficiaryCondition = json['beneficiaryCondition']?.toString();
  final String? beneficiaryNotes =
      json['beneficiaryNotes']?.toString() ?? json['note']?.toString();

  DateTime? actualStart;
  if (json['actualStart'] != null) {
    actualStart = DateTime.tryParse(json['actualStart'].toString())?.toLocal();
  }

  return ShiftModel(
    id: id,
    beneficiaryId: json['beneficiaryId']?.toString(),
    beneficiaryName: _displayText(
      json['beneficiaryName'],
      fallback: _shortIdLabel('Người thân', json['beneficiaryId']),
    ),
    caregiverId: json['caregiverId']?.toString(),
    caregiverName: _displayText(json['caregiverName'], fallback: 'Caregiver'),
    caregiverAvatar:
        _initials(_displayText(json['caregiverName'], fallback: 'CG')),
    serviceId: json['serviceTypeId']?.toString(),
    serviceName: _displayText(
      json['serviceName'],
      fallback: 'Dịch vụ chưa cập nhật',
    ),
    serviceDescription: _nullableDisplayText(json['serviceDescription']),
    scheduledStart: start,
    scheduledEnd: end,
    status: mappedStatus,
    totalPrice: escrow,
    caregiverEarning: earning,
    address: _displayText(
      json['addressText'],
      fallback: 'Địa chỉ khách hàng đã đăng ký',
    ),
    addressLatitude: (json['addressLatitude'] as num?)?.toDouble(),
    addressLongitude: (json['addressLongitude'] as num?)?.toDouble(),
    customerNote: _displayText(json['note'], fallback: ''),
    offerId: json['offerId']?.toString(),
    offerExpiresAt: json['offerExpiresAt'] == null
        ? null
        : DateTime.tryParse(json['offerExpiresAt'].toString())?.toLocal(),
    offerRank: (json['offerRank'] as num?)?.toInt(),
    isSystemMatched: json['caregiverId'] != null,
    actualStart: actualStart,
    checkoutRequestedAt: checkoutRequestedAt,
    completedAt: completedAt,
    beneficiaryAge: beneficiaryAge,
    beneficiaryGender: _nullableDisplayText(json['beneficiaryGender']),
    beneficiaryAvatarUrl: _nullableDisplayText(json['beneficiaryAvatarUrl']),
    beneficiaryRelationship: beneficiaryRelationship,
    beneficiaryCondition: beneficiaryCondition,
    beneficiaryNotes: beneficiaryNotes,
    tasks: const [],
    allowAdHocTasks: json['allowAdHocTasks'] as bool? ?? false,
    needsReview: json['needsReview'] as bool? ?? false,
  );
}

String _displayText(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableDisplayText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _shortIdLabel(String label, Object? rawId) {
  final id = rawId?.toString();
  if (id == null || id.isEmpty) return label;
  final shortId = id.length > 8 ? id.substring(0, 8) : id;
  return '$label (ID: $shortId)';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'CG';
  if (parts.length == 1) {
    final take = parts.first.length < 2 ? parts.first.length : 2;
    return parts.first.substring(0, take).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
