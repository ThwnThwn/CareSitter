import 'package:caresitter_customer/features/review/presentation/widgets/dispute_booking_fmt_list.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_layout.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

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
      return const DisputeLayout();
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
        body: DisputeBookingFmtList(
            refRow: _refRow,
            bk: bk,
            fmt: _fmt,
            reasons: _reasons,
            selectedReason: _selectedReason,
            descCtrl: _descCtrl,
            attachments: _attachments,
            pickImage: _pickImage,
            pickVideo: _pickVideo,
            setState: setState,
            isSubmitting: _isSubmitting,
            submit: _submit,
            callbackAction1: (value) => setState(() => _selectedReason = value),
            callbackAction2: (_) => setState(() {})),
      ),
    );
  }

  Widget _refRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: AppFontSizes.s13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bookingStoreProvider.notifier).openDispute(
            widget.bookingId,
            _selectedReason!,
            description: _descCtrl.text.trim(),
          );
      if (mounted) {
        setState(() => _isSubmitting = false);
        popOrGo(context, fallbackRoute: '/bookings');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Khiếu nại đã được ghi nhận. Chúng tôi sẽ liên hệ bạn sớm.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi khiếu nại: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _fmt(double v) => formatVnd(v, separator: ',', suffix: '');
}
