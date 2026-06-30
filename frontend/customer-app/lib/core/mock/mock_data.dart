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
  final List<EmergencyContact> emergencyContacts;

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
    this.emergencyContacts = const [],
  });
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
// Mock Data
// ─────────────────────────────────────────────────────────────

class MockData {
  // Người dùng hiện tại
  static const String currentUserName = 'Nguyễn Minh Tuấn';
  static const String currentUserPhone = '0901 234 567';
  static const String currentUserAvatar = 'NMT';

  // ── Beneficiaries (Người được chăm sóc) ─────────────────────
  static const List<MockBeneficiary> beneficiaries = [
    MockBeneficiary(
      id: 'b001',
      name: 'Nguyễn Văn An',
      age: 78,
      relation: 'Bố',
      avatarInitial: 'NVA',
      condition: 'Cần đồng hành sinh hoạt, hay quên việc vặt',
      careLevel: 'Trung bình',
      notes:
          'Thích nghe nhạc cổ điển và đọc báo buổi sáng. Cần người đồng hành đi dạo chiều. Không thích ồn ào.',
      emergencyContacts: [
        EmergencyContact(
            name: 'Nguyễn Minh Tuấn',
            phone: '0901234567',
            relationship: 'Con trai'),
        EmergencyContact(
            name: 'Nguyễn Thị Lan',
            phone: '0912345678',
            relationship: 'Con dâu'),
      ],
    ),
    MockBeneficiary(
      id: 'b002',
      name: 'Trần Thị Hoa',
      age: 74,
      relation: 'Mẹ',
      avatarInitial: 'TTH',
      condition: 'Khó di chuyển xa, cần hỗ trợ sinh hoạt hàng ngày',
      careLevel: 'Nặng',
      notes:
          'Cần giúp tắm gội và chuẩn bị bữa ăn. Thích nấu ăn cùng người khác. Hay nhờ mua đồ tạp hóa.',
      emergencyContacts: [
        EmergencyContact(
            name: 'Nguyễn Minh Tuấn',
            phone: '0901234567',
            relationship: 'Con trai'),
        EmergencyContact(
            name: 'Trần Văn Bình', phone: '0934567890', relationship: 'Con rể'),
      ],
    ),
    MockBeneficiary(
      id: 'b003',
      name: 'Bé Minh Khang',
      age: 4,
      relation: 'Con',
      avatarInitial: 'MK',
      condition: 'Trẻ khỏe mạnh, cần trông giữ ban ngày',
      careLevel: 'Nhẹ',
      notes:
          'Bé năng động, thích vẽ và xếp hình. Ngủ trưa lúc 13:00. Không cho xem điện thoại quá 30 phút/ngày.',
      emergencyContacts: [
        EmergencyContact(
            name: 'Nguyễn Minh Tuấn', phone: '0901234567', relationship: 'Bố'),
        EmergencyContact(
            name: 'Lê Thị Thu Hà', phone: '0956789012', relationship: 'Mẹ'),
        EmergencyContact(
            name: 'Lê Văn Quân',
            phone: '0923456789',
            relationship: 'Ông ngoại'),
      ],
    ),
  ];

  // ── Caregivers (Người chăm sóc) ──────────────────────────────
  static const List<MockCaregiver> caregivers = [
    MockCaregiver(
      id: 'cg001',
      name: 'Phạm Thị Bích Ngọc',
      avatarInitial: 'PBN',
      rating: 4.9,
      totalReviews: 127,
      completedShifts: 340,
      skills: [
        'Trông trẻ',
        'Dạy kỹ năng sống',
        'Nấu ăn',
        'Đồng hành người cao tuổi'
      ],
      experience: '5 năm',
      location: 'Quận 3, TP.HCM',
      hourlyRate: 85000,
      isAvailable: true,
      certifications: 'Chứng chỉ Chăm sóc trẻ em, Chứng chỉ Đồng hành người cao tuổi',
    ),
    MockCaregiver(
      id: 'cg002',
      name: 'Lê Văn Hùng',
      avatarInitial: 'LVH',
      rating: 4.7,
      totalReviews: 89,
      completedShifts: 210,
      skills: [
        'Đồng hành người lớn tuổi',
        'Dọn dẹp nhà cửa',
        'Nấu ăn theo khẩu vị',
        'Lái xe đưa đón'
      ],
      experience: '3 năm',
      location: 'Quận Bình Thạnh, TP.HCM',
      hourlyRate: 75000,
      isAvailable: true,
      certifications: 'Chứng chỉ Chăm sóc gia đình, Bằng lái B2',
    ),
    MockCaregiver(
      id: 'cg003',
      name: 'Trần Thị Thanh Mai',
      avatarInitial: 'TTM',
      rating: 4.8,
      totalReviews: 203,
      completedShifts: 520,
      skills: [
        'Trông trẻ sơ sinh',
        'Giúp việc nhà',
        'Dạy kỹ năng mầm non',
        'Tổ chức hoạt động vui chơi'
      ],
      experience: '7 năm',
      location: 'Quận 7, TP.HCM',
      hourlyRate: 95000,
      isAvailable: false,
      certifications: 'Cử nhân Giáo dục Mầm non, Chứng chỉ Montessori',
    ),
    MockCaregiver(
      id: 'cg004',
      name: 'Nguyễn Thị Hồng Nhung',
      avatarInitial: 'NHN',
      rating: 4.6,
      totalReviews: 54,
      completedShifts: 98,
      skills: [
        'Chăm sóc ban đêm',
        'Đồng hành người già',
        'Đọc sách truyện',
        'Hỗ trợ vận động nhẹ'
      ],
      experience: '2 năm',
      location: 'Quận 10, TP.HCM',
      hourlyRate: 70000,
      isAvailable: true,
      certifications: 'Chứng chỉ Chăm sóc người cao tuổi',
    ),
  ];

  // ── Bookings ─────────────────────────────────────────────────
  static const List<MockBooking> bookings = [
    MockBooking(
      id: 'bk001',
      beneficiaryName: 'Nguyễn Văn An',
      caregiverName: 'Phạm Thị Bích Ngọc',
      caregiverAvatar: 'PBN',
      serviceName: 'Đồng hành ban ngày',
      date: 'Hôm nay, 26/06/2026',
      time: '08:00 — 12:00',
      duration: '4 giờ',
      status: 'in_progress',
      totalPrice: 340000,
      address: '123 Nguyễn Trãi, P.2, Q.5, TP.HCM',
    ),
    MockBooking(
      id: 'bk002',
      beneficiaryName: 'Trần Thị Hoa',
      caregiverName: 'Lê Văn Hùng',
      caregiverAvatar: 'LVH',
      serviceName: 'Hỗ trợ sinh hoạt & dọn dẹp',
      date: 'Ngày mai, 27/06/2026',
      time: '09:00 — 11:00',
      duration: '2 giờ',
      status: 'confirmed',
      totalPrice: 150000,
      address: '45 Lê Lợi, P.7, Q.3, TP.HCM',
    ),
    MockBooking(
      id: 'bk003',
      beneficiaryName: 'Bé Minh Khang',
      caregiverName: 'Trần Thị Thanh Mai',
      caregiverAvatar: 'TTM',
      serviceName: 'Trông trẻ cả ngày',
      date: '28/06/2026',
      time: '07:00 — 19:00',
      duration: '12 giờ',
      status: 'confirmed',
      totalPrice: 1140000,
      address: '123 Nguyễn Trãi, P.2, Q.5, TP.HCM',
    ),
    MockBooking(
      id: 'bk004',
      beneficiaryName: 'Nguyễn Văn An',
      caregiverName: 'Nguyễn Thị Hồng Nhung',
      caregiverAvatar: 'NHN',
      serviceName: 'Đồng hành & đưa đón',
      date: '20/06/2026',
      time: '08:00 — 16:00',
      duration: '8 giờ',
      status: 'completed',
      totalPrice: 560000,
      address: '78 Cách Mạng Tháng 8, Q.10, TP.HCM',
    ),
    MockBooking(
      id: 'bk005',
      beneficiaryName: 'Trần Thị Hoa',
      caregiverName: 'Phạm Thị Bích Ngọc',
      caregiverAvatar: 'PBN',
      serviceName: 'Đồng hành ban ngày',
      date: '15/06/2026',
      time: '08:00 — 12:00',
      duration: '4 giờ',
      status: 'completed',
      totalPrice: 340000,
      address: '45 Lê Lợi, P.7, Q.3, TP.HCM',
    ),
  ];

  // ── Services ─────────────────────────────────────────────────
  static const List<MockService> services = [
    MockService(
      id: 'sv001',
      name: 'Đồng hành ban ngày',
      icon: '☀️',
      description:
          'Người chăm sóc đồng hành, trò chuyện, hỗ trợ sinh hoạt thường ngày cho người cao tuổi.',
      pricePerHour: 85000,
      category: 'Phổ biến',
    ),
    MockService(
      id: 'sv002',
      name: 'Đồng hành ban đêm',
      icon: '🌙',
      description:
          'Túc trực qua đêm, đảm bảo an toàn và hỗ trợ khi người thân cần giúp đỡ.',
      pricePerHour: 100000,
      category: 'Phổ biến',
    ),
    MockService(
      id: 'sv003',
      name: 'Trông trẻ theo giờ',
      icon: '👶',
      description:
          'Trông nom, chơi cùng và chăm sóc trẻ tại nhà theo khung giờ linh hoạt.',
      pricePerHour: 90000,
      category: 'Trẻ em',
    ),
    MockService(
      id: 'sv004',
      name: 'Giúp việc nhà',
      icon: '🏠',
      description:
          'Dọn dẹp, lau chùi, giặt ủi và sắp xếp nhà cửa ngăn nắp, sạch sẽ.',
      pricePerHour: 70000,
      category: 'Sinh hoạt',
    ),
    MockService(
      id: 'sv005',
      name: 'Nấu ăn tại nhà',
      icon: '🍲',
      description:
          'Chuẩn bị bữa ăn ngon, đủ dinh dưỡng theo khẩu vị và yêu cầu của gia đình.',
      pricePerHour: 75000,
      category: 'Sinh hoạt',
    ),
    MockService(
      id: 'sv006',
      name: 'Đưa đón & di chuyển',
      icon: '🚗',
      description:
          'Đưa đón người thân đến nơi cần thiết: chợ, thăm họ hàng, công viên và các địa điểm sinh hoạt thường ngày.',
      pricePerHour: 80000,
      category: 'Sinh hoạt',
    ),
    MockService(
      id: 'sv007',
      name: 'Trông trẻ sơ sinh',
      icon: '🍼',
      description:
          'Chăm sóc em bé từ 0–18 tháng: cho bú, tắm, ru ngủ và vệ sinh cá nhân.',
      pricePerHour: 120000,
      category: 'Trẻ em',
    ),
    MockService(
      id: 'sv008',
      name: 'Dạy kỹ năng & vui chơi',
      icon: '🎨',
      description:
          'Tổ chức hoạt động sáng tạo, giáo dục sớm và phát triển kỹ năng cho trẻ.',
      pricePerHour: 110000,
      category: 'Trẻ em',
    ),
  ];

  // ── Notifications ────────────────────────────────────────────
  static const List<MockNotification> notifications = [
    MockNotification(
      id: 'n001',
      title: 'Ca chăm sóc đang diễn ra',
      body:
          'Phạm Thị Bích Ngọc đã đến và bắt đầu ca đồng hành cho Nguyễn Văn An lúc 08:02.',
      time: '08:02 hôm nay',
      type: 'shift',
      isRead: false,
    ),
    MockNotification(
      id: 'n002',
      title: 'Xác nhận đặt lịch thành công',
      body:
          'Lịch ngày 27/06 với Lê Văn Hùng đã được xác nhận. Người chăm sóc sẽ đến đúng giờ.',
      time: '07:30 hôm nay',
      type: 'booking',
      isRead: false,
    ),
    MockNotification(
      id: 'n003',
      title: 'Nhắc nhở — Lịch hẹn ngày mai',
      body:
          'Bạn có lịch chăm sóc cho Trần Thị Hoa vào 09:00 ngày mai với Lê Văn Hùng.',
      time: 'Hôm qua, 20:00',
      type: 'booking',
      isRead: true,
    ),
    MockNotification(
      id: 'n004',
      title: 'Đánh giá ca chăm sóc',
      body:
          'Ca ngày 20/06 đã hoàn thành. Hãy đánh giá dịch vụ của Nguyễn Thị Hồng Nhung!',
      time: '20/06, 17:00',
      type: 'shift',
      isRead: true,
    ),
    MockNotification(
      id: 'n005',
      title: 'Thanh toán thành công',
      body:
          'Thanh toán 560,000đ cho ca ngày 20/06 đã được ghi nhận thành công.',
      time: '20/06, 16:45',
      type: 'payment',
      isRead: true,
    ),
  ];

  // ── Stats (cho Home dashboard) ────────────────────────────────
  static const int totalBookingsThisMonth = 7;
  static const int completedBookings = 23;
  static const double totalSpentThisMonth = 2530000;
  static const double averageRatingGiven = 4.8;
}
