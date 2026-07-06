import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _callHotline() async {
    final url = Uri.parse('tel:19001234');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendEmail() async {
    final url = Uri.parse('mailto:support@caresitter.com?subject=Support%20Caregiver');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _submitRequest() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _titleController.clear();
        _descController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yêu cầu hỗ trợ của bạn đã được gửi. Chúng tôi sẽ phản hồi trong 2 giờ tới.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trung tâm trợ giúp'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hotline Card
            _buildContactCard(
              title: 'Tổng đài hỗ trợ 24/7',
              subtitle: '1900 1234 (1,000 đ/phút)',
              icon: Icons.phone_in_talk_rounded,
              color: AppColors.primary,
              onTap: _callHotline,
            ),
            const SizedBox(height: 16),
            // Email Card
            _buildContactCard(
              title: 'Gửi email hỗ trợ',
              subtitle: 'support@caresitter.com',
              icon: Icons.mail_outline_rounded,
              color: AppColors.info,
              onTap: _sendEmail,
            ),
            const SizedBox(height: 32),

            // Form Title
            const Text(
              'Gửi yêu cầu hỗ trợ trực tuyến',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề vấn đề',
                      hintText: 'Ví dụ: Lỗi không check-in được',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập nội dung chi tiết' : null,
                    decoration: InputDecoration(
                      labelText: 'Mô tả chi tiết',
                      hintText: 'Mô tả sự cố bạn đang gặp phải và cung cấp thêm thông tin nếu có...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Gửi yêu cầu',
                    onPressed: _isLoading ? null : _submitRequest,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}
