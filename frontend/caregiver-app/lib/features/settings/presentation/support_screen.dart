import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _attachments = [];
  bool _submitting = false;

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
    final url =
        Uri.parse('mailto:support@caresitter.com?subject=Support%20Caregiver');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _pickAttachments() async {
    final files =
        await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
    if (!mounted || files.isEmpty) return;
    setState(() => _attachments.addAll(files.take(5 - _attachments.length)));
  }

  Future<String> _uploadAttachment(XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
      'folder': 'support',
    });
    final response = await ref
        .read(dioClientProvider)
        .postForm<Map<String, dynamic>>('/media/upload', formData);
    final url = response.data?['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw const AppApiException(
          message: 'Máy chủ không trả về URL tệp đính kèm.');
    }
    return url;
  }

  Future<void> _submitRequest() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final attachmentUrls = <String>[];
      for (final file in _attachments) {
        attachmentUrls.add(await _uploadAttachment(file));
      }
      final response =
          await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/support/tickets',
        data: {
          'type': 'GENERAL',
          'priority': 'MEDIUM',
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'attachmentUrls': attachmentUrls,
        },
      );
      if (!mounted) return;
      final ticketId = response.data?['id']?.toString();
      _titleController.clear();
      _descController.clear();
      setState(() => _attachments.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ticketId == null
            ? 'Yêu cầu hỗ trợ đã được gửi.'
            : 'Đã gửi yêu cầu hỗ trợ. Mã: $ticketId'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(apiErrorMessage(error)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    validator: (val) => val == null || val.isEmpty
                        ? 'Vui lòng nhập tiêu đề'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề vấn đề',
                      hintText: 'Ví dụ: Lỗi không check-in được',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    validator: (val) => (val?.trim().length ?? 0) < 10
                        ? 'Nội dung cần ít nhất 10 ký tự'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Mô tả chi tiết',
                      hintText:
                          'Mô tả sự cố bạn đang gặp phải và cung cấp thêm thông tin nếu có...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Đính kèm ảnh (${_attachments.length}/5)',
                    icon: Icons.attach_file_rounded,
                    isOutlined: true,
                    onPressed:
                        _attachments.length < 5 ? _pickAttachments : null,
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_attachments.length, (index) {
                        return InputChip(
                          label: Text(_attachments[index].name,
                              overflow: TextOverflow.ellipsis),
                          onDeleted: _submitting
                              ? null
                              : () =>
                                  setState(() => _attachments.removeAt(index)),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Gửi yêu cầu',
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _submitRequest,
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
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}
