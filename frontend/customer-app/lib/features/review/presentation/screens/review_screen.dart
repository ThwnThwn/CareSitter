import 'package:caresitter_customer/features/review/presentation/widgets/review_layout.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/review_row.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/review_rating_content.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/review_has_unsaved_changes_content.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/review_tags_selected_tags_content.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/review_booking_content.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/review_comment_ctrl_rating_content.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
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
      return const ReviewLayout();
    }
    final bk = matches.first;
    return ReviewHasUnsavedChangesContent(
        hasUnsavedChanges: _hasUnsavedChanges,
        action1: (context, requestExit) => Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Đánh giá dịch vụ'),
                leading: AppBackButton(
                  fallbackRoute: AppRoutes.bookings,
                  onPressed: requestExit,
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Caregiver info
                  ReviewBookingContent(bk: bk),
                  const SizedBox(height: AppSpacing.lg),

                  // Star rating
                  FadeSlideStaggered(
                    index: 1,
                    child: Column(
                      children: [
                        const Center(
                            child: Text('Bạn cảm thấy thế nào?',
                                style: TextStyle(
                                    fontSize: AppFontSizes.s16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary))),
                        const SizedBox(height: AppSpacing.compact),
                        ReviewRow(
                            action1: (i) => GestureDetector(
                                  onTap: () => setState(() => _rating = i + 1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm),
                                    child: Icon(
                                      i < _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 44,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                )),
                        const SizedBox(height: AppSpacing.sm),
                        ReviewRatingContent(rating: _rating),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Tags
                  ReviewTagsSelectedTagsContent(
                      tags: _tags,
                      selectedTags: _selectedTags,
                      setState: setState),
                  const SizedBox(height: AppSpacing.section),

                  // Comment & Submit
                  ReviewCommentCtrlRatingContent(
                      commentCtrl: _commentCtrl,
                      rating: _rating,
                      isSubmitting: _isSubmitting,
                      submit: _submit,
                      bk: bk),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ));
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
        AppToast.success(context, 'Đã gửi đánh giá dịch vụ');
        popOrGo(context, fallbackRoute: AppRoutes.bookings);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.error(
          context,
          e is AppApiException
              ? e.message
              : 'Không thể gửi đánh giá. Vui lòng thử lại.',
        );
      }
    }
  }
}
