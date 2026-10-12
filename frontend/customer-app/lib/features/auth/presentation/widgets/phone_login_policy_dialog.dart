import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
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
                  'CareSitter cam kết bảo vệ thông tin cá nhân của bạn.\n\n'
                  '• Thông tin của bạn chỉ dùng để cung cấp dịch vụ chăm sóc.\n'
                  '• Chúng tôi không chia sẻ dữ liệu với bên thứ ba.\n'
                  '• Bạn có thể yêu cầu xóa tài khoản bất kỳ lúc nào.\n\n'
                  'Bằng cách tiếp tục, bạn đồng ý với các điều khoản trên.',
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
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
