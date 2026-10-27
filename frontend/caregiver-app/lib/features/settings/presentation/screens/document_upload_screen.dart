import 'package:caregiver_app/features/settings/presentation/widgets/document_identity_images.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/document_identity_number_field.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/document_certificate_chips.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/document_certificate_heading.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:caregiver_app/core/error/failure.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  final String docTitle;

  const DocumentUploadScreen({super.key, required this.docTitle});

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cccdController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _front;
  XFile? _back;
  final List<XFile> _certificates = [];
  bool _submitting = false;

  @override
  void dispose() {
    _cccdController.dispose();
    super.dispose();
  }

  Future<void> _pickRequiredImage(bool front) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;
    setState(() => front ? _front = file : _back = file);
  }

  Future<void> _pickCertificates() async {
    final files =
        await _picker.pickMultiImage(imageQuality: 88, maxWidth: 1800);
    if (!mounted || files.isEmpty) return;
    setState(() => _certificates.addAll(files.take(10 - _certificates.length)));
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_front == null || _back == null) {
      _showMessage('Vui lòng chọn đủ mặt trước và mặt sau CCCD.', true);
      return;
    }

    setState(() => _submitting = true);
    final controller = ref.read(profileProvider.notifier);
    try {
      await controller.submitKyc(
        cccdNumber: _cccdController.text,
        cccdFront: File(_front!.path),
        cccdBack: File(_back!.path),
        certificates: _certificates.map((file) => File(file.path)).toList(),
      );
      if (!mounted || ref.read(profileProvider.notifier) != controller) return;
      _showMessage('Hồ sơ KYC đã được gửi và đang chờ duyệt.', false);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage(apiErrorMessage(error), true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message, bool error) {
    if (error) {
      AppToast.error(context, message, title: 'Chưa thể gửi hồ sơ');
    } else {
      AppToast.success(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nộp hồ sơ KYC'),
        leading: const AppBackButton(fallbackRoute: '/settings/documents'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'Ảnh phải rõ nét, không bị che góc. Hồ sơ chỉ chuyển sang chờ duyệt sau khi máy chủ nhận đủ dữ liệu.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.lg),
            DocumentIdentityNumberField(
                cccdController: _cccdController,
                callbackAction1: (value) {
                  final text = value?.trim() ?? '';
                  return RegExp(r'^(\d{9}|\d{12})$').hasMatch(text)
                      ? null
                      : 'Số CCCD phải gồm 9 hoặc 12 chữ số';
                }),
            const SizedBox(height: AppSpacing.md),
            DocumentIdentityImages(
                front: _front,
                back: _back,
                callbackAction1: () => _pickRequiredImage(true),
                callbackAction2: () => _pickRequiredImage(false)),
            const SizedBox(height: AppSpacing.lg),
            DocumentCertificateHeading(certificates: _certificates),
            const SizedBox(height: AppSpacing.compact),
            AppButton(
              label: 'Chọn ảnh chứng chỉ',
              icon: Icons.add_photo_alternate_outlined,
              isOutlined: true,
              onPressed: _certificates.length < 10 ? _pickCertificates : null,
            ),
            if (_certificates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.compact),
              DocumentCertificateChips(
                  certificates: _certificates,
                  submitting: _submitting,
                  onRemove: (index) =>
                      setState(() => _certificates.removeAt(index))),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Gửi hồ sơ KYC',
              icon: Icons.cloud_upload_outlined,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
