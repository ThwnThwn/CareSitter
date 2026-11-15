import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingConsentContent extends StatelessWidget {
  const BookingConsentContent({super.key});
  @override
  Widget build(BuildContext context) => Container(
      height: (MediaQuery.sizeOf(context).height * 0.42).clamp(220.0, 320.0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border)),
      child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final section in const [
          (
            '1. Cam kết dịch vụ',
            'CareSitter kết nối bạn với người chăm sóc đã được duyệt hồ sơ để hỗ trợ sinh hoạt phi y tế. Thông tin kinh nghiệm và kỹ năng cần được xem trong hồ sơ của từng người chăm sóc.'
          ),
          (
            '2. Trách nhiệm của khách hàng',
            'Bạn cam kết cung cấp thông tin chính xác về người được chăm sóc, bao gồm nhu cầu hỗ trợ, sở thích sinh hoạt và các lưu ý đặc biệt. Thông tin sai lệch có thể ảnh hưởng đến chất lượng dịch vụ và CareSitter không chịu trách nhiệm trong trường hợp này.'
          ),
          (
            '3. Quyền riêng tư & dữ liệu',
            'Thông tin được xử lý theo Chính sách Bảo mật của CareSitter và quyền truy cập của từng vai trò. Khi bạn chia sẻ thực đơn cho ca, người chăm sóc được phân công chỉ nhận nội dung món ăn cần thiết cho việc hỗ trợ sinh hoạt.'
          ),
          (
            '4. Chính sách hủy & hoàn tiền',
            'Lịch đã thanh toán có thể được hoàn toàn bộ số tiền khách đã trả khi hủy trước giờ bắt đầu, hoặc khi không thể cung cấp người chăm sóc theo chính sách hiện hành. Khi ca đã bắt đầu hoặc cần xác minh no-show, yêu cầu được xử lý qua hỗ trợ/khiếu nại. Số tiền dự kiến được kiểm tra trên từng lịch trước khi hủy; thời gian nhận tiền phụ thuộc đơn vị thanh toán.'
          ),
          (
            '5. Xử lý sự cố',
            'Khi xảy ra sự cố trong ca, người chăm sóc cần liên hệ các liên hệ khẩn cấp đã cung cấp và gửi thông tin qua kênh hỗ trợ của CareSitter. Hỗ trợ trong ứng dụng không thay thế dịch vụ cấp cứu.'
          ),
          (
            '6. Bồi thường',
            'Yêu cầu liên quan đến thiệt hại hoặc chất lượng ca được tiếp nhận qua quy trình hỗ trợ và khiếu nại. Kết quả hoàn tiền hoặc bồi thường phụ thuộc việc xác minh và điều khoản áp dụng cho trường hợp cụ thể.'
          ),
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.$1,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(section.$2)
                  ]))
      ])));
}
