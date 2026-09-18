import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = [
    {
      'q': 'Làm thế nào để đổi/hủy ca chăm sóc?',
      'a':
          'Bạn có thể hủy ca miễn phí trước 24 giờ kể từ khi ca bắt đầu. Truy cập vào mục "Lịch hẹn", chọn ca muốn hủy và nhấn "Hủy ca". Đối với việc đổi ca, vui lòng hủy ca cũ và đặt lại ca mới.'
    },
    {
      'q': 'Tôi thanh toán bằng hình thức nào?',
      'a':
          'Hiện tại CareSitter hỗ trợ thanh toán trực tuyến qua cổng VNPay. Các phương thức khác chưa được hỗ trợ trong ứng dụng.'
    },
    {
      'q': 'Làm sao để biết Caregiver đã đến nơi?',
      'a':
          'Khi Caregiver bắt đầu di chuyển hoặc đã đến nơi, ứng dụng sẽ gửi thông báo đẩy (push notification) cho bạn. Bạn có thể theo dõi trực tiếp vị trí trên bản đồ trong tab "Đang diễn ra".'
    },
    {
      'q': 'Caregiver có được đào tạo chuyên môn không?',
      'a':
          '100% Caregiver trên hệ thống đều phải trải qua quá trình xác minh danh tính, lý lịch tư pháp và vượt qua bài kiểm tra kỹ năng chăm sóc và hỗ trợ sinh hoạt trước khi được nhận việc.'
    },
    {
      'q': 'Nếu không hài lòng về Caregiver thì phải làm sao?',
      'a':
          'Sau mỗi ca, bạn có thể đánh giá số sao và để lại nhận xét. Nếu có sự cố nghiêm trọng, vui lòng nhấn "Khiếu nại" trong chi tiết ca để bộ phận CSKH xử lý và hoàn tiền nếu lỗi thuộc về CareSitter.'
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Câu hỏi thường gặp'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final faq = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: AppColors.primary,
                collapsedIconColor: AppColors.textSecondary,
                title: Text(
                  faq['q']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faq['a']!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
