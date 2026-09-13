import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/presentation/providers/profile_provider.dart';

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
    try {
      await ref.read(profileProvider.notifier).submitKyc(
            cccdNumber: _cccdController.text,
            cccdFront: File(_front!.path),
            cccdBack: File(_back!.path),
            certificates: _certificates.map((file) => File(file.path)).toList(),
          );
      if (!mounted) return;
      _showMessage('Hồ sơ KYC đã được gửi và đang chờ duyệt.', false);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage(apiErrorMessage(error), true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
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
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Ảnh phải rõ nét, không bị che góc. Hồ sơ chỉ chuyển sang chờ duyệt sau khi máy chủ nhận đủ dữ liệu.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _cccdController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'Số CCCD',
                hintText: 'Nhập 9 hoặc 12 chữ số',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                return RegExp(r'^(\d{9}|\d{12})$').hasMatch(text)
                    ? null
                    : 'Số CCCD phải gồm 9 hoặc 12 chữ số';
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ImagePickerCard(
                    label: 'Mặt trước CCCD',
                    file: _front,
                    onTap: () => _pickRequiredImage(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImagePickerCard(
                    label: 'Mặt sau CCCD',
                    file: _back,
                    onTap: () => _pickRequiredImage(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text('Chứng chỉ chuyên môn (không bắt buộc)',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${_certificates.length}/10',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Chọn ảnh chứng chỉ',
              icon: Icons.add_photo_alternate_outlined,
              isOutlined: true,
              onPressed: _certificates.length < 10 ? _pickCertificates : null,
            ),
            if (_certificates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_certificates.length, (index) {
                  return InputChip(
                    label: Text('Chứng chỉ ${index + 1}'),
                    onDeleted: _submitting
                        ? null
                        : () => setState(() => _certificates.removeAt(index)),
                  );
                }),
              ),
            ],
            const SizedBox(height: 32),
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

class _ImagePickerCard extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onTap;

  const _ImagePickerCard(
      {required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: file == null ? AppColors.border : AppColors.primary),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(file == null ? Icons.add_a_photo_outlined : Icons.check_circle,
                color: file == null ? AppColors.textHint : AppColors.primary,
                size: 36),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(file == null ? 'Chạm để chọn ảnh' : file!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
