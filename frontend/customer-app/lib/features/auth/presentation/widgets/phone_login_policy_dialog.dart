import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/config/legal_links.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class PhoneLoginPolicyDialog extends StatelessWidget {
  const PhoneLoginPolicyDialog({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Điều khoản & Chính sách'),
              content: const SingleChildScrollView(
                child: Text(
                  'CareSitter xử lý thông tin tài khoản và dữ liệu bạn cung cấp để vận hành dịch vụ, bảo vệ an toàn và hỗ trợ người dùng.\n\n'
                  'Dữ liệu cần thiết có thể được chia sẻ với caregiver được phân công và các nhà cung cấp hạ tầng, bản đồ, thông báo hoặc thanh toán theo Chính sách quyền riêng tư.\n\n'
                  'Bạn có thể xem điều khoản đầy đủ và yêu cầu xóa tài khoản bất kỳ lúc nào.',
                ),
              ),
              actions: [
                const TextButton(
                  onPressed: LegalLinks.openPrivacy,
                  child: Text('Quyền riêng tư'),
                ),
                const TextButton(
                  onPressed: LegalLinks.openTerms,
                  child: Text('Điều khoản'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          child: const Text(
            'Điều khoản sử dụng & Chính sách bảo mật',
            style:
                TextStyle(fontSize: AppFontSizes.s12, color: AppColors.primary),
          ),
        ),
      );
}
