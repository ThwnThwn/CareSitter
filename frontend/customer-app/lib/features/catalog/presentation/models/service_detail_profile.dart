class ServiceDetailProfile {
  const ServiceDetailProfile({
    required this.imageAsset,
    required this.heroLabel,
    required this.summary,
  });

  final String imageAsset;
  final String heroLabel;
  final String summary;

  static ServiceDetailProfile forCode(String code) {
    final value = code.toUpperCase();
    if (value.contains('COMPANION') || value.contains('DONGHANH')) {
      return const ServiceDetailProfile(
        imageAsset: 'assets/images/service-companion.jpg',
        heroLabel: 'Trò chuyện, sẻ chia và đồng hành mỗi ngày',
        summary:
            'Một người bạn tận tâm cùng người thân trò chuyện, giải trí và duy trì nhịp sinh hoạt quen thuộc.',
      );
    }
    if (value.contains('NIGHT') || value.contains('DEM')) {
      return const ServiceDetailProfile(
        imageAsset: 'assets/images/service-night.jpg',
        heroLabel: 'Có người đồng hành an tâm trong khung giờ tối',
        summary:
            'Hỗ trợ sinh hoạt buổi tối, giữ không gian an toàn và cập nhật kịp thời cho gia đình.',
      );
    }
    if (value.contains('DAY')) {
      return const ServiceDetailProfile(
        imageAsset: 'assets/images/service-day.jpg',
        heroLabel: 'Hỗ trợ trọn buổi với lịch trình linh hoạt',
        summary:
            'Đồng hành nhiều giờ với các hoạt động sinh hoạt, bữa ăn và vận động nhẹ theo thỏa thuận.',
      );
    }
    return const ServiceDetailProfile(
      imageAsset: 'assets/images/service-essential.jpg',
      heroLabel: 'Hỗ trợ các nhu cầu sinh hoạt thiết yếu',
      summary:
          'Hỗ trợ chu đáo các hoạt động thường ngày để người thân sinh hoạt thuận tiện và an toàn hơn.',
    );
  }
}
