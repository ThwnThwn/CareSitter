import 'package:caregiver_app/features/home/presentation/controllers/home_selectors.dart';
import 'package:caregiver_app/features/home/presentation/controllers/offer_action_controller.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_sticky_header.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_kpi_cards.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_card.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_today_timeline.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_chart.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_safety_disclaimer.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/earnings/presentation/controllers/earnings_controller.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final processingOfferId = ref.watch(offerActionControllerProvider);
    final selected = ref.watch(homeShiftsProvider);
    final todayShifts = selected.today;
    final pendingShifts = selected.offers;
    final scheduledOrActiveShifts = selected.scheduled;
    final earnings = ref.watch(earningsProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          const HomeStickyHeader(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.s100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                HomeKpiCards(
                  todayCount: todayShifts.length,
                  monthTotal: earnings.monthTotal,
                  rating: profile.rating,
                  totalReviews: profile.totalReviews,
                ),
                const SizedBox(height: AppSpacing.md),
                if (pendingShifts.isNotEmpty) ...[
                  HomeOfferCard(
                    booking: pendingShifts.first,
                    pendingCount: pendingShifts.length,
                    processingOfferId: processingOfferId,
                    turnaroundWarning: turnaroundWarning(
                        pendingShifts.first, scheduledOrActiveShifts),
                    selectDeclineReason: _selectDeclineReason,
                    runOfferAction: _runOfferAction,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                HomeTodayTimeline(shifts: todayShifts),
                const SizedBox(height: AppSpacing.md),
                HomeEarningsChart(
                  last7Days: earnings.last7Days,
                  completedShifts: earnings.completedShifts,
                  monthTotal: earnings.monthTotal,
                ),
                const SizedBox(height: AppSpacing.md),
                const HomeSafetyDisclaimer(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runOfferAction(
    BuildContext context,
    String bookingId, {
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final result = await ref
        .read(offerActionControllerProvider.notifier)
        .run(bookingId, action);
    if (!context.mounted || result == OfferActionResult.ignored) return;
    if (result == OfferActionResult.success) {
      AppToast.success(context, successMessage);
    } else {
      AppToast.error(
        context,
        'Ca vừa thay đổi hoặc bạn đang trùng lịch. Vui lòng thử lại.',
        title: 'Chưa thể cập nhật ca',
      );
    }
  }

  Future<String?> _selectDeclineReason(BuildContext context) {
    const reasons = <String>[
      'Trùng lịch',
      'Địa điểm quá xa',
      'Không phù hợp kỹ năng',
      'Không thể nhận ca trong thời gian này',
    ];
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lý do từ chối ca',
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Thông tin này giúp hệ thống ghép ca phù hợp hơn cho bạn.',
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            for (final reason in reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 4,
                title: Text(reason,
                    style:
                        GoogleFonts.beVietnamPro(fontSize: AppFontSizes.s15)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(sheetContext).pop(reason),
              ),
          ],
        ),
      ),
    );
  }
}
