import 'package:caregiver_app/features/settings/presentation/widgets/support_description_field.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/support_title_field.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/support_attachment_chips.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

class SupportRequestForm extends StatelessWidget {
  const SupportRequestForm(
      {super.key,
      required this.formKey,
      required this.titleController,
      required this.descController,
      required this.attachments,
      required this.pickAttachments,
      required this.submitting,
      required this.onRemove,
      required this.submitRequest,
      required this.callbackAction2,
      required this.callbackAction3});
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descController;
  final List<XFile> attachments;
  final Future<void> Function() pickAttachments;
  final bool submitting;
  final void Function(int) onRemove;
  final Future<void> Function() submitRequest;
  final String? Function(String?) callbackAction2;
  final String? Function(String?) callbackAction3;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: Column(
          children: [
            SupportTitleField(
                titleController: titleController,
                callbackAction1: callbackAction2),
            const SizedBox(height: AppSpacing.md),
            SupportDescriptionField(
                descController: descController,
                callbackAction1: callbackAction3),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Đính kèm ảnh (${attachments.length}/5)',
              icon: Icons.attach_file_rounded,
              isOutlined: true,
              onPressed: attachments.length < 5 ? pickAttachments : null,
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SupportAttachmentChips(
                  attachments: attachments,
                  submitting: submitting,
                  onRemove: onRemove),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Gửi yêu cầu',
              isLoading: submitting,
              onPressed: submitting ? null : submitRequest,
            ),
          ],
        ),
      );
}
