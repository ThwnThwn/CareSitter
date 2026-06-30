import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../booking/application/booking_store.dart';

class DisputeScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const DisputeScreen({super.key, required this.bookingId});

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  String? _selectedReason;
  final _descCtrl = TextEditingController();
  bool _isSubmitting = false;
  final List<XFile> _attachments = [];
  final ImagePicker _picker = ImagePicker();

  bool get _hasUnsavedChanges =>
      _selectedReason != null ||
      _descCtrl.text.trim().isNotEmpty ||
      _attachments.isNotEmpty;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_attachments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chỉ được đính kèm tối đa 5 hình ảnh/tệp.')),
      );
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      setState(() {
        _attachments.addAll(picked.take(5 - _attachments.length));
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_attachments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chỉ được đính kèm tối đa 5 hình ảnh/tệp.')),
      );
      return;
    }
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _attachments.add(video);
      });
    }
  }

  final _reasons = [
    'Caregiver đến trễ / bỏ ca',
    'Chất lượng hỗ trợ sinh hoạt không đạt',
    'Hành vi không phù hợp',
    'Tính phí sai',
    'Tài sản bị hư hỏng',
    'Lý do khác',
  ];

  @override
  Widget build(BuildContext context) {
    final matches =
        ref.watch(bookingStoreProvider).where((b) => b.id == widget.bookingId);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy booking')));
    }
    final bk = matches.first;
    return DiscardChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      fallbackRoute: '/bookings',
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Khiếu nại'),
          leading: AppBackButton(
            fallbackRoute: '/bookings',
            onPressed: requestExit,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                  'Khiếu nại sẽ được xem xét trong 24h. Chúng tôi sẽ liên hệ bạn qua số điện thoại đã đăng ký.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.warning, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Booking reference
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                _refRow('Mã lịch hẹn', '#${bk.id.toUpperCase()}'),
                const Divider(height: 16),
                _refRow('Người chăm sóc', bk.caregiverName),
                const Divider(height: 16),
                _refRow('Ngày', bk.date),
                const Divider(height: 16),
                _refRow('Tổng tiền', '${_fmt(bk.totalPrice)}đ'),
              ]),
            ),
            const SizedBox(height: 20),

            // Reason selection
            const Text('Lý do khiếu nại *',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ..._reasons.map((r) {
              final isSelected = r == _selectedReason;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.errorLight
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected ? AppColors.error : AppColors.border,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color:
                            isSelected ? AppColors.error : AppColors.textHint,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(r,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.error
                                : AppColors.textPrimary)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Description
            const Text('Mô tả chi tiết *',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText:
                    'Mô tả sự việc xảy ra một cách chi tiết và khách quan...',
              ),
            ),
            const SizedBox(height: 16),

            // Attachments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Đính kèm bằng chứng (tuỳ chọn)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('${_attachments.length}/5 tệp',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _attachments.length < 5 ? _pickImage : null,
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Ảnh'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _attachments.length < 5 ? _pickVideo : null,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Video'),
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  itemBuilder: (ctx, i) {
                    final file = _attachments[i];
                    final isVideo = file.path.endsWith('.mp4') ||
                        file.path.endsWith('.mov') ||
                        file.path.endsWith('.avi');
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isVideo
                                ? const Center(
                                    child: Icon(Icons.play_circle_fill,
                                        size: 32, color: AppColors.primary))
                                : Image.file(File(file.path),
                                    width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _attachments.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedReason != null &&
                      _descCtrl.text.length >= 20 &&
                      !_isSubmitting
                  ? _submit
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Gửi khiếu nại',
                      style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Center(
                child: Text(
              _descCtrl.text.length < 20
                  ? 'Vui lòng mô tả ít nhất 20 ký tự'
                  : '',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _refRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ref.read(bookingStoreProvider.notifier).openDispute(
            widget.bookingId,
            '${_selectedReason!}: ${_descCtrl.text.trim()}',
          );
      setState(() => _isSubmitting = false);
      popOrGo(context, fallbackRoute: '/bookings');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                '✅ Khiếu nại đã được ghi nhận. Chúng tôi sẽ liên hệ bạn sớm.')),
      );
    }
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
