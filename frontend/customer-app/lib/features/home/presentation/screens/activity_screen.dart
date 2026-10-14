import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_content.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_content.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

import '../widgets/activity_section_heading.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingStoreProvider);
    final now = DateTime.now();

    final active = bookings.where((b) => b.isLiveTrackingAt(now)).toList();

    final recent = bookings.where((b) {
      final status = b.presentationStatusAt(now);
      return status == 'completed' ||
          status == 'cancelled' ||
          status == 'confirmed' ||
          status == 'caregiver_accepted' ||
          status == 'pending';
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────
          const ActivityContent(),

          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Active shift section ─────────────────
                if (active.isNotEmpty)
                  FadeSlideStaggered(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ActivitySectionHeading(title: 'Đang diễn ra'),
                        const SizedBox(height: AppSpacing.control),
                        ...active.map((b) => ActivityActiveCard(booking: b)),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),

                // ── Recent section ───────────────────────
                if (recent.isNotEmpty) ActivityRecentContent(recent: recent),

                if (active.isEmpty && recent.isEmpty)
                  const FadeSlideStaggered(
                    index: 0,
                    child: ActivityEmptyState(),
                  ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
