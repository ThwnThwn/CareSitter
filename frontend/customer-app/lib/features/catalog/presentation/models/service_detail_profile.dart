import 'package:flutter/material.dart';

class ServiceDetailTimelineEntry {
  const ServiceDetailTimelineEntry(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class ServiceDetailProfile {
  const ServiceDetailProfile({
    required this.imageAsset,
    required this.heroLabel,
    required this.summary,
    required this.timeline,
    required this.tasks,
  });

  final String imageAsset;
  final String heroLabel;
  final String summary;
  final List<ServiceDetailTimelineEntry> timeline;
  final List<String> tasks;

  static ServiceDetailProfile forCode(String code) {
    final value = code.toUpperCase();
    if (value.contains('COMPANION') || value.contains('DONGHANH')) {
      return const ServiceDetailProfile(
        imageAsset: 'assets/images/service-companion.jpg',
        heroLabel: 'Trò chuyện, sẻ chia và đồng hành mỗi ngày',
        summary:
            'Một người bạn tận tâm cùng người thân trò chuyện, giải trí và duy trì nhịp sinh hoạt quen thuộc.',
        timeline: [
          ServiceDetailTimelineEntry(
            Icons.waving_hand_outlined,
            'Chào hỏi và thống nhất hoạt động',
            'Caregiver đọc ghi chú, hỏi thăm và cùng người được chăm sóc chọn hoạt động phù hợp.',
          ),
          ServiceDetailTimelineEntry(
            Icons.forum_outlined,
            'Trò chuyện và hoạt động yêu thích',
            'Đọc sách, nghe nhạc, chơi trò chơi nhẹ hoặc cùng xem lại ảnh gia đình.',
          ),
          ServiceDetailTimelineEntry(
            Icons.directions_walk_rounded,
            'Vận động nhẹ và nghỉ ngơi',
            'Đi lại nhẹ nhàng trong phạm vi an toàn theo khả năng và mong muốn.',
          ),
          ServiceDetailTimelineEntry(
            Icons.fact_check_outlined,
            'Bàn giao cuối ca',
            'Ghi lại các hoạt động đã thực hiện và cập nhật cho gia đình.',
          ),
        ],
        tasks: [
          'Xác nhận ghi chú chăm sóc',
          'Trò chuyện và bầu bạn',
          'Hỗ trợ hoạt động giải trí nhẹ',
          'Nhắc lịch sinh hoạt do gia đình cung cấp',
          'Bàn giao cuối ca',
        ],
      );
    }
    if (value.contains('NIGHT') || value.contains('DEM')) {
      return const ServiceDetailProfile(
        imageAsset: 'assets/images/service-night.jpg',
        heroLabel: 'Có người đồng hành an tâm trong khung giờ tối',
        summary:
            'Hỗ trợ sinh hoạt buổi tối, giữ không gian an toàn và cập nhật kịp thời cho gia đình.',
        timeline: [
          ServiceDetailTimelineEntry(
            Icons.nights_stay_outlined,
            'Nhận ca và kiểm tra không gian',
            'Đối chiếu ghi chú, lối đi, ánh sáng và các vật dụng cần thiết.',
          ),
          ServiceDetailTimelineEntry(
            Icons.dinner_dining_outlined,
            'Hỗ trợ sinh hoạt buổi tối',
            'Chuẩn bị đồ uống hoặc bữa nhẹ và hỗ trợ các hoạt động cá nhân đã thống nhất.',
          ),
          ServiceDetailTimelineEntry(
            Icons.notifications_active_outlined,
            'Nhắc lịch và quan sát an toàn',
            'Nhắc lịch do gia đình cung cấp và hỗ trợ khi người thân cần di chuyển.',
          ),
          ServiceDetailTimelineEntry(
            Icons.fact_check_outlined,
            'Bàn giao cuối ca',
            'Cập nhật tình hình, công việc đã hoàn thành và các lưu ý phát sinh.',
          ),
        ],
        tasks: [
          'Xác nhận ghi chú ca tối',
          'Hỗ trợ sinh hoạt cá nhân',
          'Chuẩn bị đồ uống hoặc bữa nhẹ',
          'Nhắc lịch sinh hoạt',
          'Bàn giao cuối ca',
        ],
      );
    }
    if (value.contains('DAY')) {
      return const ServiceDetailProfile(
        imageAsset: 'assets/images/service-day.jpg',
        heroLabel: 'Hỗ trợ trọn buổi với lịch trình linh hoạt',
        summary:
            'Đồng hành nhiều giờ với các hoạt động sinh hoạt, bữa ăn và vận động nhẹ theo thỏa thuận.',
        timeline: [
          ServiceDetailTimelineEntry(
            Icons.assignment_outlined,
            'Bắt đầu ca và rà soát kế hoạch',
            'Xác nhận phạm vi công việc, ưu tiên trong ngày và thông tin liên hệ của gia đình.',
          ),
          ServiceDetailTimelineEntry(
            Icons.home_outlined,
            'Hỗ trợ sinh hoạt tại nhà',
            'Hỗ trợ vệ sinh cá nhân, thay đồ và sắp xếp không gian sinh hoạt gọn gàng.',
          ),
          ServiceDetailTimelineEntry(
            Icons.restaurant_outlined,
            'Chuẩn bị bữa ăn',
            'Chuẩn bị món ăn theo nguyên liệu, khẩu vị và hướng dẫn gia đình cung cấp.',
          ),
          ServiceDetailTimelineEntry(
            Icons.fact_check_outlined,
            'Tổng kết và bàn giao',
            'Hoàn tất checklist, ghi nhật ký và trao đổi lại với gia đình.',
          ),
        ],
        tasks: [
          'Xác nhận kế hoạch chăm sóc',
          'Hỗ trợ vệ sinh và thay đồ',
          'Chuẩn bị bữa ăn hoặc đồ uống',
          'Đồng hành vận động nhẹ',
          'Bàn giao cuối ca',
        ],
      );
    }
    return const ServiceDetailProfile(
      imageAsset: 'assets/images/service-essential.jpg',
      heroLabel: 'Hỗ trợ các nhu cầu sinh hoạt thiết yếu',
      summary:
          'Hỗ trợ chu đáo các hoạt động thường ngày để người thân sinh hoạt thuận tiện và an toàn hơn.',
      timeline: [
        ServiceDetailTimelineEntry(
          Icons.assignment_outlined,
          'Xác nhận ghi chú chăm sóc',
          'Caregiver đọc lại phạm vi hỗ trợ và các lưu ý do gia đình cung cấp.',
        ),
        ServiceDetailTimelineEntry(
          Icons.accessibility_new_rounded,
          'Hỗ trợ sinh hoạt cá nhân',
          'Hỗ trợ vệ sinh, thay đồ và di chuyển trong phạm vi đã thống nhất.',
        ),
        ServiceDetailTimelineEntry(
          Icons.restaurant_outlined,
          'Chuẩn bị bữa ăn hoặc đồ uống',
          'Chuẩn bị theo nguyên liệu và hướng dẫn do gia đình cung cấp.',
        ),
        ServiceDetailTimelineEntry(
          Icons.fact_check_outlined,
          'Bàn giao cuối ca',
          'Ghi nhận công việc đã hoàn thành và cập nhật cho gia đình.',
        ),
      ],
      tasks: [
        'Xác nhận ghi chú chăm sóc',
        'Hỗ trợ vệ sinh và thay đồ',
        'Chuẩn bị bữa ăn hoặc đồ uống',
        'Nhắc lịch sinh hoạt',
        'Bàn giao cuối ca',
      ],
    );
  }
}
