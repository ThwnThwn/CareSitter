import 'package:flutter/material.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _is2FAEnabled = true;
  String _selectedMethod = 'sms';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác thực 2 lớp (2FA)'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.elevated,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.security, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bảo mật tài khoản',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _is2FAEnabled
                            ? 'Tài khoản của bạn đang được bảo vệ an toàn.'
                            : 'Bật 2FA để thêm một lớp bảo mật.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Main Toggle
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: const Text('Xác thực 2 lớp',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Yêu cầu mã xác nhận mỗi khi đăng nhập trên thiết bị mới.'),
              value: _is2FAEnabled,
              onChanged: (v) {
                setState(() => _is2FAEnabled = v);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        v ? 'Đã bật Xác thực 2 lớp' : 'Đã tắt Xác thực 2 lớp'),
                    backgroundColor:
                        v ? AppColors.success : AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),

          if (_is2FAEnabled) ...[
            const SizedBox(height: 24),
            const Text(
              'Phương thức xác thực',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: RadioGroup<String>(
                groupValue: _selectedMethod,
                onChanged: (value) {
                  if (value == null) return;
                  if (value == 'app') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tính năng xác thực qua Ứng dụng sẽ sớm ra mắt',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedMethod = value);
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Tin nhắn SMS (Mặc định)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Gửi mã OTP về số điện thoại đã đăng ký của bạn.'),
                      value: 'sms',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    RadioListTile<String>(
                      title: Text('Ứng dụng Authenticator',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Dùng Google Authenticator hoặc Authy để tạo mã.'),
                      value: 'app',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
