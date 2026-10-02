import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const ReviewScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  final _tags = [
    'Đúng giờ',
    'Tận tâm',
    'Chuyên nghiệp',
    'Nhẹ nhàng',
    'Giao tiếp tốt',
    'Sạch sẽ'
  ];
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  bool get _hasUnsavedChanges =>
      _rating > 0 ||
      _commentCtrl.text.trim().isNotEmpty ||
      _selectedTags.isNotEmpty;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

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
          title: const Text('Đánh giá dịch vụ'),
          leading: AppBackButton(
            fallbackRoute: '/bookings',
            onPressed: requestExit,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Caregiver info
            FadeSlideStaggered(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(bk.caregiverAvatar ?? bk.caregiverInitials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(bk.caregiverName ?? 'Người chăm sóc',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text(bk.serviceName ?? 'Dịch vụ chăm sóc',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13)),
                        Text(bk.date,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12)),
                      ])),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Star rating
            FadeSlideStaggered(
              index: 1,
              child: Column(
                children: [
                  const Center(
                      child: Text('Bạn cảm thấy thế nào?',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        5,
                        (i) => GestureDetector(
                              onTap: () => setState(() => _rating = i + 1),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  i < _rating ? Icons.star : Icons.star_border,
                                  size: 44,
                                  color: AppColors.secondary,
                                ),
                              ),
                            )),
                  ),
                  const SizedBox(height: 8),
                  Center(
                      child: Text(
                    _rating == 0
                        ? 'Chọn số sao'
                        : [
                            '',
                            'Tệ 😞',
                            'Chưa tốt 😐',
                            'Được 🙂',
                            'Tốt 😊',
                            'Xuất sắc ⭐'
                          ][_rating],
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tags
            FadeSlideStaggered(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Điểm nổi bật',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() => isSelected
                            ? _selectedTags.remove(tag)
                            : _selectedTags.add(tag)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Comment & Submit
            FadeSlideStaggered(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nhận xét chi tiết',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText:
                          'Chia sẻ trải nghiệm của bạn để giúp người khác...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _rating > 0 && !_isSubmitting
                        ? () => _submit(bk)
                        : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Gửi đánh giá'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BookingModel bk) async {
    setState(() => _isSubmitting = true);
    try {
      final tagsString =
          _selectedTags.isEmpty ? null : _selectedTags.join(', ');
      await ref.read(bookingStoreProvider.notifier).markReviewed(
            widget.bookingId,
            caregiverId: bk.caregiverId,
            rating: _rating,
            comment: _commentCtrl.text.trim(),
            experienceTags: tagsString,
          );
      if (mounted) {
        setState(() => _isSubmitting = false);
        popOrGo(context, fallbackRoute: '/bookings');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cảm ơn bạn đã gửi đánh giá dịch vụ!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi đánh giá: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
