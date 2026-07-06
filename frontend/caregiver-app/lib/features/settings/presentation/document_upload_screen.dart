import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String docTitle;

  const DocumentUploadScreen({super.key, required this.docTitle});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  bool _hasImage = false;
  bool _isUploading = false;
  String? _selectedFileName;

  void _pickImage(String source) {
    setState(() => _isUploading = true);
    // Simulate image loading/uploading
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _hasImage = true;
          _selectedFileName = source == 'camera' ? 'IMG_CAMERA_0823.JPG' : 'DOC_SCAN_PREVIEW.PNG';
        });
      }
    });
  }

  void _submitDocument() {
    setState(() => _isUploading = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi tài liệu "${widget.docTitle}" để duyệt'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.docTitle),
        leading: const AppBackButton(fallbackRoute: '/settings/documents'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Instructions ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Vui lòng tải lên ảnh chụp mặt trước rõ nét của ${widget.docTitle}. Đảm bảo đủ ánh sáng, không bị lóa và rõ chữ.',
                      style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Upload Card ──
            Center(
              child: _buildUploadCard(),
            ),
            const SizedBox(height: 40),

            // ── Submit Button ──
            AppButton(
              label: 'Gửi yêu cầu phê duyệt',
              onPressed: _hasImage && !_isUploading ? _submitDocument : null,
              isLoading: _isUploading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    if (_isUploading) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Đang xử lý ảnh...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasImage) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // Preview box
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_present_rounded, size: 56, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFileName ?? 'document.jpg',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ảnh đã chọn thành công',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _hasImage = false;
                        _selectedFileName = null;
                      });
                    },
                    child: const Text('Thay đổi', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showPickOptions(),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              'Chạm để chụp hoặc chọn ảnh',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Hỗ trợ JPG, PNG (Tối đa 5MB)',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Chụp ảnh bằng Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage('camera');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Chọn ảnh từ Thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage('gallery');
              },
            ),
          ],
        ),
      ),
    );
  }
}
