import 'package:caregiver_app/features/settings/presentation/controllers/support_submission_controller.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/support_request_form.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/support_contact_card.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final files =
        await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
    if (!mounted || files.isEmpty) return;
    setState(() => _attachments.addAll(files.take(5 - _attachments.length)));
  }

  Future<void> _submitRequest() async {
    if (ref.read(supportSubmissionControllerProvider) ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final result = await ref
        .read(supportSubmissionControllerProvider.notifier)
        .submit(_titleController.text, _descController.text, _attachments);
    if (!mounted || result is SupportIgnored) return;
    if (result is SupportSubmitted) {
      _titleController.clear();
      _descController.clear();
      setState(() => _attachments.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.ticketId == null
              ? 'Yêu cầu hỗ trợ đã được gửi.'
              : 'Đã gửi yêu cầu hỗ trợ. Mã: ${result.ticketId!}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating));
    } else if (result is SupportFailed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(supportSubmissionControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trung tâm trợ giúp'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactCard(
              title: 'Chat hỗ trợ',
              subtitle: 'Gửi tin nhắn và theo dõi phản hồi trong ứng dụng',
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
              onTap: () => context.push('/settings/support/chat'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Form Title
            const Text(
              'Gửi yêu cầu hỗ trợ trực tuyến',
              style: TextStyle(
                  fontSize: AppFontSizes.s16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),

            SupportRequestForm(
                formKey: _formKey,
                titleController: _titleController,
                descController: _descController,
                attachments: _attachments,
                pickAttachments: _pickAttachments,
                submitting: submitting,
                onRemove: (index) =>
                    setState(() => _attachments.removeAt(index)),
                submitRequest: _submitRequest,
                callbackAction2: (val) =>
                    val == null || val.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                callbackAction3: (val) => (val?.trim().length ?? 0) < 10
                    ? 'Nội dung cần ít nhất 10 ký tự'
                    : null),
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
  }) =>
      SupportContactCard(
          onTap: onTap,
          color: color,
          icon: icon,
          title: title,
          subtitle: subtitle);
}
