import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'activity_section_heading.dart';
import 'activity_recent_row.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class ActivityRecentContent extends StatelessWidget {
  const ActivityRecentContent({super.key, required this.recent});
  final List<BookingModel> recent;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ActivitySectionHeading(title: 'Gần đây'),
            const SizedBox(height: AppSpacing.control),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(recent.length, (i) {
                  final b = recent[i];
                  final isLast = i == recent.length - 1;
                  return Column(
                    key: ValueKey('recent_${b.id}'),
                    children: [
                      ActivityRecentRow(booking: b),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: AppColors.surfaceVariant),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Xem lịch sử link
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/bookings'),
                icon: const Text(
                  'Xem lịch sử',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSizes.s14,
                  ),
                ),
                label: const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primary, size: 16),
              ),
            ),
          ],
        ),
      );
}
