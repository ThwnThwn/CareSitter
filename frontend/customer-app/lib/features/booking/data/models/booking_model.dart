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
  final DateTime? checkoutPendingReviewAt;
  final String? checkoutSource;
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
    this.syncVersion = 0,
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
      status == 'cancelled' ||
      status == 'matching_failed' ||
      status == 'disputed' ||
      status == 'refunded';
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
  bool get isSystemMatched => true;
  String get paymentLabel => 'Ví CareSitter';
  double get platformRevenue => platformFeeAmount.toDouble();
  double get caregiverEarning => (escrowAmount - platformFeeAmount).toDouble();
  DateTime? get consentAcceptedAt => createdAt;
  DateTime? get checkoutRequestedAt => checkoutPendingReviewAt;
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
    DateTime? checkoutPendingReviewAt,
    String? checkoutSource,
    DateTime? cancelledAt,
    String? cancelReason,
    DateTime? updatedAt,
    bool? isReviewed,
    List<dynamic>? tasks,
    int? syncVersion,
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
      syncVersion: syncVersion ?? this.syncVersion,
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
      status: _normalizeStatus(_string(json['status']) ?? 'draft'),
      escrowAmount: _int(json['escrowAmount']),
      platformFeeAmount: _int(json['platformFeeAmount']),
      cancelledAt: _parseNullableApiDateTime(json['cancelledAt']),
      cancelReason: _string(json['cancelReason']),
      createdAt: _parseNullableApiDateTime(json['createdAt']) ?? now,
      updatedAt: _parseNullableApiDateTime(json['updatedAt']) ?? now,
      caregiverName: _string(json['caregiverName']),
      caregiverAvatar: _string(json['caregiverAvatar']),
      beneficiaryName: _string(json['beneficiaryName']),
      addressText: _string(json['addressText']),
      serviceName: _string(json['serviceName']),
      syncVersion: _int(json['syncVersion']),
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
        id: _string(json['id']) ?? '',
        bookingId: _string(json['bookingId']) ?? '',
        caregiverId: _string(json['caregiverId']) ?? '',
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        accuracyMeters: _nullableDouble(json['accuracyMeters']),
        speed: _nullableDouble(json['speed']),
        heading: _nullableDouble(json['heading']),
        recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  LatLng get latLng => LatLng(latitude, longitude);

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

// ── Booking list response (paginated) ──────────────────────────────────────

class BookingListResponse {
  final List<BookingModel> items;
  final int total;
  final int page;
  final int pageSize;

  /// Cursor mới nhất của customer — client lưu để bắt đầu delta sync.
  final int syncCursor;

  const BookingListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.syncCursor = 0,
  });

  factory BookingListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(BookingModel.fromJson)
            .toList()
        : <BookingModel>[];
    return BookingListResponse(
      items: items,
      total: _int(json['total']) ?? items.length,
      page: _int(json['page']) ?? 1,
      pageSize: _int(json['pageSize']) ?? items.length,
      syncCursor: _int(json['syncCursor']) ?? 0,
    );
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
