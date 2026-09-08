// Mock data CareSitter v1.1.0
// Dữ liệu mẫu cho Customer App — dùng khi chưa kết nối backend thật

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────

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

class MockBeneficiary {
  final String id;
  final String name;
  final int age;
  final String relation;
  final String avatarInitial;
  final String condition;
  final String careLevel; // Nhẹ / Trung bình / Nặng
  final String notes;
  final String address;
  final String? defaultAddressId;
  final List<EmergencyContact> emergencyContacts;
  final String? avatarPath;

  const MockBeneficiary({
    required this.id,
    required this.name,
    required this.age,
    required this.relation,
    required this.avatarInitial,
    required this.condition,
    required this.careLevel,
    required this.notes,
    this.address = '',
    this.defaultAddressId,
    this.emergencyContacts = const [],
    this.avatarPath,
  });

  MockBeneficiary copyWith({
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
    bool clearAvatarPath = false,
  }) {
    return MockBeneficiary(
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
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
    );
  }
}

class MockCaregiver {
  final String id;
  final String name;
  final String avatarInitial;
  final double rating;
  final int totalReviews;
  final int completedShifts;
  final List<String> skills;
  final String experience;
  final String location;
  final double hourlyRate;
  final bool isAvailable;
  final String certifications;

  const MockCaregiver({
    required this.id,
    required this.name,
    required this.avatarInitial,
    required this.rating,
    required this.totalReviews,
    required this.completedShifts,
    required this.skills,
    required this.experience,
    required this.location,
    required this.hourlyRate,
    required this.isAvailable,
    required this.certifications,
  });
}

class MockCareTask {
  final String title;
  final bool isCompleted;

  const MockCareTask({
    required this.title,
    this.isCompleted = false,
  });

  MockCareTask copyWith({bool? isCompleted}) {
    return MockCareTask(
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class MockBooking {
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
  final String status;
  final double totalPrice;
  final String address;
  final bool isSystemMatched;
  final bool isDemoBooking;
  final String paymentLabel;
  final DateTime? consentAcceptedAt;
  final DateTime? checkoutRequestedAt;
  final DateTime? completedAt;
  final bool isReviewed;
  final String? disputeReason;
  final List<MockCareTask> tasks;
  final double platformRevenue;
  final double caregiverEarning;

  const MockBooking({
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
    required this.status,
    required this.totalPrice,
    required this.address,
    this.isSystemMatched = false,
    this.isDemoBooking = true,
    this.paymentLabel = 'Booking demo',
    this.consentAcceptedAt,
    this.checkoutRequestedAt,
    this.completedAt,
    this.isReviewed = false,
    this.disputeReason,
    this.tasks = const [],
    this.platformRevenue = 0,
    this.caregiverEarning = 0,
  });

  MockBooking copyWith({
    String? status,
    DateTime? checkoutRequestedAt,
    DateTime? completedAt,
    bool? isReviewed,
    String? disputeReason,
    List<MockCareTask>? tasks,
    double? platformRevenue,
    double? caregiverEarning,
  }) {
    return MockBooking(
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
      status: status ?? this.status,
      totalPrice: totalPrice,
      address: address,
      isSystemMatched: isSystemMatched,
      isDemoBooking: isDemoBooking,
      paymentLabel: paymentLabel,
      consentAcceptedAt: consentAcceptedAt,
      checkoutRequestedAt: checkoutRequestedAt ?? this.checkoutRequestedAt,
      completedAt: completedAt ?? this.completedAt,
      isReviewed: isReviewed ?? this.isReviewed,
      disputeReason: disputeReason ?? this.disputeReason,
      tasks: tasks ?? this.tasks,
      platformRevenue: platformRevenue ?? this.platformRevenue,
      caregiverEarning: caregiverEarning ?? this.caregiverEarning,
    );
  }
}

class MockService {
  final String id;
  final String name;
  final String icon;
  final String description;
  final double pricePerHour;
  final String category;

  const MockService({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.pricePerHour,
    required this.category,
  });
}

class MockNotification {
  final String id;
  final String title;
  final String body;
  final String time;
  final String type; // booking / shift / system / payment
  final bool isRead;

  const MockNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    required this.isRead,
  });
}

// ─────────────────────────────────────────────────────────────
// Mock Data — CÁC CLASS MÔ HÌNH (MODEL DEFINITIONS ONLY)
// Static data đã được xoá — mọi data đều lấy từ backend API thật.
// File này chỉ giữ class definitions để các màn hình UI hiện tại
// không bị vỡ. Sẽ được dọn dẹp dần khi migrate từng màn hình.
// ─────────────────────────────────────────────────────────────

class MockData {
  // Tất cả static data đã bị xoá.
  // Dùng các Store/Provider tương ứng để lấy dữ liệu thật từ backend.
}


