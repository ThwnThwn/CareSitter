import 'package:latlong2/latlong.dart';

// ── Booking response từ API ──────────────────────────────────────────────────

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
  final String
      status; // pending | confirmed | caregiver_en_route | in_progress | ...
  final int escrowAmount;
  final int platformFeeAmount;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Fields enriched từ related APIs (people, catalog)
  final String? caregiverName;
  final String? caregiverAvatar;
  final String? beneficiaryName;
  final String? addressText;
  final String? serviceName;

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
    required this.status,
    required this.escrowAmount,
    required this.platformFeeAmount,
    this.cancelledAt,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
    this.caregiverName,
    this.caregiverAvatar,
    this.beneficiaryName,
    this.addressText,
    this.serviceName,
    this.isReviewed = false,
    this.tasks = const [],
  });

  final bool isReviewed;
  final List<dynamic> tasks;

  // ── Derived helpers ───────────────────────────────────────────────────────

  bool get isActive => const {
        'draft',
        'pending_payment',
        'confirmed',
        'caregiver_accepted',
        'caregiver_en_route',
        'in_progress',
        'checkout_pending_review',
        'crisis',
      }.contains(status);

  bool get isCompleted => status == 'completed';
  bool get isCancelled =>
      status == 'cancelled' || status == 'disputed' || status == 'refunded';
  bool get isPendingPayment => status == 'pending_payment';
  bool get isEnRoute => status == 'caregiver_en_route';
  bool get isInProgress => status == 'in_progress';
  bool get isCheckoutPending => status == 'checkout_pending_review';
  bool get isCrisis => status == 'crisis';

  String get date => displayDate;
  String get time => displayTime;
  String get duration => displayDuration;
  String get address => addressText ?? 'Địa chỉ ca trực';
  double get totalPrice => escrowAmount.toDouble();
  String? get disputeReason => cancelReason;
  bool get isDemoBooking => false;
  bool get isSystemMatched => true;
  String get paymentLabel => 'Ví CareSitter';
  double get platformRevenue => platformFeeAmount.toDouble();
  double get caregiverEarning => (escrowAmount - platformFeeAmount).toDouble();
  DateTime? get consentAcceptedAt => createdAt;
  DateTime? get checkoutRequestedAt => actualEnd;
  DateTime? get completedAt => isCompleted ? updatedAt : null;

  String get displayDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date =
        DateTime(scheduledStart.year, scheduledStart.month, scheduledStart.day);
    if (date == today) {
      return 'Hôm nay, ${scheduledStart.day}/${scheduledStart.month}';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (date == tomorrow) {
      return 'Ngày mai, ${scheduledStart.day}/${scheduledStart.month}';
    }
    return '${scheduledStart.day}/${scheduledStart.month}/${scheduledStart.year}';
  }

  String get displayTime {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(scheduledStart.hour)}:${pad(scheduledStart.minute)} '
        '– ${pad(scheduledEnd.hour)}:${pad(scheduledEnd.minute)}';
  }

  String get displayDuration {
    final hours = scheduledEnd.difference(scheduledStart).inHours;
    return '$hours giờ';
  }

  String get caregiverInitials {
    if (caregiverName == null || caregiverName!.isEmpty) return '?';
    final parts =
        caregiverName!.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  BookingModel copyWith({
    String? status,
    String? caregiverId,
    String? caregiverName,
    String? caregiverAvatar,
    DateTime? actualStart,
    DateTime? actualEnd,
    DateTime? cancelledAt,
    String? cancelReason,
    DateTime? updatedAt,
    bool? isReviewed,
    List<dynamic>? tasks,
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
      status: status ?? this.status,
      escrowAmount: escrowAmount,
      platformFeeAmount: platformFeeAmount,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverAvatar: caregiverAvatar ?? this.caregiverAvatar,
      beneficiaryName: beneficiaryName,
      addressText: addressText,
      serviceName: serviceName,
      isReviewed: isReviewed ?? this.isReviewed,
      tasks: tasks ?? this.tasks,
    );
  }

  // ── fromJson ─────────────────────────────────────────────────────────────

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String,
        beneficiaryId: json['beneficiaryId'] as String,
        caregiverId: json['caregiverId'] as String?,
        addressId: json['addressId'] as String,
        serviceTypeId: json['serviceTypeId'] as String,
        scheduledStart: DateTime.parse(json['scheduledStart'] as String),
        scheduledEnd: DateTime.parse(json['scheduledEnd'] as String),
        actualStart: json['actualStart'] != null
            ? DateTime.parse(json['actualStart'] as String)
            : null,
        actualEnd: json['actualEnd'] != null
            ? DateTime.parse(json['actualEnd'] as String)
            : null,
        status: _normalizeStatus(json['status'] as String),
        escrowAmount: json['escrowAmount'] as int,
        platformFeeAmount: json['platformFeeAmount'] as int,
        cancelledAt: json['cancelledAt'] != null
            ? DateTime.parse(json['cancelledAt'] as String)
            : null,
        cancelReason: json['cancelReason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        caregiverName: json['caregiverName'] as String?,
        caregiverAvatar: json['caregiverAvatar'] as String?,
        beneficiaryName: json['beneficiaryName'] as String?,
        addressText: json['addressText'] as String?,
        serviceName: json['serviceName'] as String?,
      );

  /// Chuyển status về lower_snake_case thống nhất.
  /// BE có thể trả UPPER_SNAKE (dữ liệu cũ/cache) hoặc lower_snake (mới).
  /// Hàm này đảm bảo FE luôn nhận lower_snake_case.
  static String _normalizeStatus(String raw) {
    var value = raw.trim().replaceAll('-', '_');
    value = value.replaceAllMapped(
      RegExp(r'([A-Z]+)([A-Z][a-z])'),
      (m) => '${m.group(1)}_${m.group(2)}',
    );
    value = value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)}_${m.group(2)}',
    );
    value = value.toLowerCase();

    return switch (value) {
      'en_route' => 'caregiver_en_route',
      'assigned' => 'caregiver_accepted',
      'checkout_requested' => 'checkout_pending_review',
      'payment_confirmed' => 'confirmed',
      _ => value,
    };
  }
}

// ── GPS Track response ──────────────────────────────────────────────────────

class GpsTrackModel {
  final String id;
  final String bookingId;
  final String caregiverId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  const GpsTrackModel({
    required this.id,
    required this.bookingId,
    required this.caregiverId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  factory GpsTrackModel.fromJson(Map<String, dynamic> json) => GpsTrackModel(
        id: json['id'] as String,
        bookingId: json['bookingId'] as String,
        caregiverId: json['caregiverId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );

  LatLng get latLng => LatLng(latitude, longitude);
}

// ── Booking list response (paginated) ──────────────────────────────────────

class BookingListResponse {
  final List<BookingModel> items;
  final int total;
  final int page;
  final int pageSize;

  const BookingListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory BookingListResponse.fromJson(Map<String, dynamic> json) =>
      BookingListResponse(
        items: (json['items'] as List)
            .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
      );
}
