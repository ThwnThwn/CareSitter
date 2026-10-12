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
            'CareSitter cam kết cung cấp người chăm sóc đã được xác minh danh tính, kiểm tra lý lịch và đào tạo chuyên môn. Mọi caregiver phải tuân thủ quy tắc ứng xử nghiêm ngặt trong suốt ca làm việc.'
          ),
          (
            '2. Trách nhiệm của khách hàng',
            'Bạn cam kết cung cấp thông tin chính xác về người được chăm sóc, bao gồm nhu cầu hỗ trợ, sở thích sinh hoạt và các lưu ý đặc biệt. Thông tin sai lệch có thể ảnh hưởng đến chất lượng dịch vụ và CareSitter không chịu trách nhiệm trong trường hợp này.'
          ),
          (
            '3. Quyền riêng tư & dữ liệu',
            'Thông tin cá nhân của người được chăm sóc được bảo mật tuyệt đối theo Chính sách Bảo mật của CareSitter. Dữ liệu chỉ được chia sẻ với caregiver được phân công và các cơ quan có thẩm quyền khi cần thiết.'
          ),
          (
            '4. Chính sách hủy & hoàn tiền',
            'Hủy trước 24h: hoàn 100%. Hủy trước 12h: hoàn 50%. Hủy trong vòng 2h hoặc khi caregiver đã đến: không hoàn tiền. Trường hợp khẩn cấp sẽ được xem xét riêng.'
          ),
          (
            '5. Xử lý sự cố',
            'Trong trường hợp xảy ra sự cố trong ca chăm sóc, caregiver sẽ liên hệ ngay với các liên hệ khẩn cấp bạn đã cung cấp. CareSitter có đội hỗ trợ 24/7 để xử lý các tình huống khẩn cấp.'
          ),
          (
            '6. Bồi thường',
            'CareSitter có bảo hiểm trách nhiệm nghề nghiệp cho mọi ca làm việc. Trong trường hợp xảy ra thiệt hại do lỗi của caregiver, CareSitter sẽ hỗ trợ theo quy trình giải quyết khiếu nại.'
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
