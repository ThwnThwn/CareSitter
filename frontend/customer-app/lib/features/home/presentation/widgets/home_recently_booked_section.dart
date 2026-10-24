import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeRecentlyBookedSection extends StatelessWidget {
  const HomeRecentlyBookedSection(
      {super.key, required this.bookings, required this.buildRebookCard});
  final List<BookingModel> bookings;
  final Widget Function(BookingModel, BuildContext) buildRebookCard;
  @override
  Widget build(BuildContext context) {
    // Lọc những booking đã hoàn thành, lấy caregiver unique gần nhất
    final completed = bookings
        .where((b) =>
            b.presentationStatusAt(DateTime.now()) == 'completed' ||
            b.presentationStatusAt(DateTime.now()) == 'caregiver_completed')
        .toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));

    // Deduplicate theo caregiverId
    final seen = <String>{};
    final unique = completed
        .where((b) {
          if (b.caregiverId == null) return false;
          return seen.add(b.caregiverId!);
        })
        .take(5)
        .toList();

    if (unique.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Đã đặt gần đây',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            HomeHoverButton(
              onTap: () => context.push(AppRoutes.bookings),
              child: const Text(
                'Xem thêm',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.inset),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < unique.length; i++) ...[
                  buildRebookCard(unique[i], context),
                  if (i != unique.length - 1)
                    const SizedBox(width: AppSpacing.compact),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
