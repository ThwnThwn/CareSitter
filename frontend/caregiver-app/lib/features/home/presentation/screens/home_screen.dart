import 'package:caregiver_app/features/home/presentation/controllers/home_selectors.dart';
import 'package:caregiver_app/features/home/presentation/controllers/offer_action_controller.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_sticky_header.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_kpi_cards.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_card.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_today_timeline.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_chart.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_safety_disclaimer.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
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
          _buildStickyHeader(context, ref),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.s100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildKpiCards(
                  todayCount: todayShifts.length,
                  monthTotal: earnings.monthTotal,
                  rating: profile.rating,
                  totalReviews: profile.totalReviews,
                ),
                const SizedBox(height: AppSpacing.md),
                if (pendingShifts.isNotEmpty) ...[
                  _buildNewBookingRequest(
                    context,
                    ref,
                    pendingShifts.first,
                    pendingCount: pendingShifts.length,
                    processingOfferId: processingOfferId,
                    scheduledOrActiveShifts: scheduledOrActiveShifts,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _buildTodayTimeline(context, todayShifts),
                const SizedBox(height: AppSpacing.md),
                _buildEarningsChart(
                  context: context,
                  last7Days: earnings.last7Days,
                  completedShifts: earnings.completedShifts,
                  monthTotal: earnings.monthTotal,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSafetyDisclaimer(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky Header ──────────────────────────────────────
  Widget _buildStickyHeader(BuildContext context, WidgetRef ref) =>
      HomeStickyHeader(ref: ref, shortName: _shortName, initials: _initials);

  String _shortName(String displayName) {
    final parts =
        displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'Caregiver' : parts.last;
  }

  String _initials(String displayName) {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'CG';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  // ── KPI Summary Cards ──────────────────────────────────
  Widget _buildKpiCards({
    required int todayCount,
    required double monthTotal,
    required double rating,
    required int totalReviews,
  }) =>
      HomeKpiCards(
          monthTotal: monthTotal,
          rating: rating,
          totalReviews: totalReviews,
          todayCount: todayCount);

  // ── New Booking Request Card (Pulse) ───────────────────
  Widget _buildNewBookingRequest(
          BuildContext context, WidgetRef ref, ShiftModel booking,
          {required int pendingCount,
          required String? processingOfferId,
          required List<ShiftModel> scheduledOrActiveShifts}) =>
      HomeOfferCard(
          booking: booking,
          processingOfferId: processingOfferId,
          countdownLabel: _countdownLabel,
          turnaroundWarning: turnaroundWarning,
          scheduledOrActiveShifts: scheduledOrActiveShifts,
          pendingCount: pendingCount,
          offerLocationLabel: _offerLocationLabel,
          formatPrice: _formatPrice,
          selectDeclineReason: _selectDeclineReason,
          runOfferAction: _runOfferAction,
          ref: ref);

  String? _countdownLabel(Duration? remaining) {
    if (remaining == null) return null;
    if (remaining <= Duration.zero) return null;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return 'Còn ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result == OfferActionResult.success
          ? successMessage
          : 'Ca vừa thay đổi hoặc bạn đang trùng lịch. Vui lòng thử lại.'),
      backgroundColor: result == OfferActionResult.success
          ? AppColors.success
          : AppColors.error,
    ));
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

  // ── Today Timeline ─────────────────────────────────────
  Widget _buildTodayTimeline(BuildContext context, List<ShiftModel> shifts) =>
      HomeTodayTimeline(todayLabel: _todayLabel, shifts: shifts);

  // ── Helpers ────────────────────────────────────────────
  /// Nhãn ngày hôm nay động: "Thứ Hai, 09/09"
  String _todayLabel() {
    const dayNames = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final now = DateTime.now();
    final dayName = dayNames[now.weekday - 1];
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$dayName, $d/$m';
  }

  // ── Earnings Bar Chart ─────────────────────────────────
  Widget _buildEarningsChart({
    required BuildContext context,
    required List<double> last7Days,
    required int completedShifts,
    required double monthTotal,
  }) =>
      HomeEarningsChart(
          last7Days: last7Days,
          formatPrice: _formatPrice,
          completedShifts: completedShifts,
          monthTotal: monthTotal);

  // ── Non-Medical Safety Disclaimer ──────────────────────
  Widget _buildSafetyDisclaimer() => const HomeSafetyDisclaimer();

  String _formatPrice(double price) =>
      formatVnd(price, compact: true, suffix: '', round: true);

  String _offerLocationLabel(ShiftModel booking) {
    final address = booking.address.trim();
    if (address.isEmpty || address == 'Địa chỉ khách hàng đã đăng ký') {
      return 'Địa chỉ theo booking';
    }
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) return parts.take(2).join(', ');
    return address;
  }
}
