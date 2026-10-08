import 'package:latlong2/latlong.dart';

// ── CareTask model (shared: caregiver & customer views) ────────────────
class CareTaskModel {
  final String id;
  final String title;
  final String? description;
  final bool isRequired;
  final bool requiresPhoto;
  final int sortOrder;
  final String status; // PENDING | COMPLETED | SKIPPED
  final List<String> photoUrls;

  /// PACKAGE | CAREGIVER_AD_HOC | SYSTEM
  final String source;
  final String? skipReason;
  final DateTime? completedAt;

  const CareTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.isRequired = false,
    this.requiresPhoto = false,
    this.sortOrder = 0,
    this.status = 'PENDING',
    this.photoUrls = const [],
    this.source = 'PACKAGE',
    this.skipReason,
    this.completedAt,
  });

  bool get isCompleted =>
      status.toUpperCase() == 'DONE' || status.toUpperCase() == 'COMPLETED';
  bool get isSkipped => status.toUpperCase() == 'SKIPPED';
  bool get isAdHoc => source == 'CAREGIVER_AD_HOC';
  bool get isTerminal => isCompleted || isSkipped;

  factory CareTaskModel.fromApi(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase() ?? 'PENDING';
    return CareTaskModel(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? 'Nhiệm vụ',
      description: json['description']?.toString(),
      isRequired: json['isRequired'] as bool? ?? false,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status: status,
      photoUrls: (json['photoUrls'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      source: json['source']?.toString() ?? 'PACKAGE',
      skipReason: json['skipReason']?.toString(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())?.toLocal()
          : null,
    );
  }

  CareTaskModel copyWith({String? status, List<String>? photoUrls}) {
    final nextStatus = status ?? this.status;
    return CareTaskModel(
      id: id,
      title: title,
      description: description,
      isRequired: isRequired,
      requiresPhoto: requiresPhoto,
      sortOrder: sortOrder,
      status: nextStatus,
      photoUrls: photoUrls ?? this.photoUrls,
      source: source,
      skipReason: skipReason,
      completedAt: completedAt,
    );
  }
}

// ── Booking response ừ API ──────────────────────────────────────────────────

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

  // ── Derived helpers ───────────────────────────────────────────────────────

  bool get isActive => const {
        'draft',
        'pending_payment',
        'payment_reconciliation_pending',
        'needs_manual_review',
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

  /// Trạng thái an toàn để hiển thị trên UI.
  ///
  /// `IN_PROGRESS` và `CHECKOUT_PENDING_REVIEW` chỉ hợp lệ sau khi backend
  /// ghi nhận `actualStart`. Dữ liệu cũ hoặc dữ liệu bị chỉnh trực tiếp có thể
  /// còn status live dù ca đã huỷ/chưa check-in; không được biến các bản ghi đó
  /// thành một ca đang diễn ra trên ứng dụng khách hàng.
  String presentationStatusAt(DateTime now) {
    final normalizedStatus = status.toLowerCase();
    const cancelledStatuses = {'cancelled', 'refunded', 'disputed'};

    if (cancelledAt != null && !cancelledStatuses.contains(normalizedStatus)) {
      return 'cancelled';
    }

    const checkedInStatuses = {'in_progress', 'checkout_pending_review'};
    final hasValidCheckIn = actualStart != null && !actualStart!.isAfter(now);
    if (checkedInStatuses.contains(normalizedStatus) && !hasValidCheckIn) {
      return caregiverId == null ? 'confirmed' : 'caregiver_accepted';
    }

    return normalizedStatus;
  }

  bool isLiveTrackingAt(DateTime now) {
    final displayStatus = presentationStatusAt(now);
    return displayStatus == 'caregiver_en_route' ||
        displayStatus == 'in_progress' ||
        displayStatus == 'checkout_pending_review';
  }

  String get date => displayDate;
  String get time => displayTime;
  String get duration => displayDuration;
  String get address => addressText ?? 'Địa chỉ ca trực';
  double get totalPrice => escrowAmount.toDouble();
  String? get disputeReason => cancelReason;
  bool get isSystemMatched => true;
  String get paymentLabel => 'Thanh toán CareSitter';
  int get payableAmount => customerPayableAmount ?? escrowAmount;
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
      status: _normalizeStatus(_string(json['status']) ?? 'draft'),
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
  final int version;
  final int bookingVersion;
  final DateTime? receivedAt;
  final String? sessionId;
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
    this.version = 0,
    this.bookingVersion = 0,
    this.receivedAt,
    this.sessionId,
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
        version: (json['version'] as num?)?.toInt() ?? 0,
        bookingVersion: (json['bookingVersion'] as num?)?.toInt() ?? 0,
        receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
        sessionId: _string(json['sessionId']),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        accuracyMeters: _nullableDouble(json['accuracyMeters']),
        speed: _nullableDouble(json['speed']),
        heading: _nullableDouble(json['heading']),
        recordedAt: DateTime.parse(
            (json['capturedAt'] ?? json['recordedAt']).toString()),
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
