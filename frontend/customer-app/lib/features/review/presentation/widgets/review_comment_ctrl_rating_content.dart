import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class ReviewCommentCtrlRatingContent extends StatelessWidget {
  const ReviewCommentCtrlRatingContent(
      {super.key,
      required this.commentCtrl,
      required this.rating,
      required this.isSubmitting,
      required this.submit,
      required this.bk});
  final TextEditingController commentCtrl;
  final int rating;
  final bool isSubmitting;
  final Future<void> Function(BookingModel) submit;
  final BookingModel bk;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhận xét chi tiết',
                style: TextStyle(
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: commentCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ trải nghiệm của bạn để giúp người khác...',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: rating > 0 && !isSubmitting ? () => submit(bk) : null,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Gửi đánh giá'),
            ),
          ],
        ),
      );
}
