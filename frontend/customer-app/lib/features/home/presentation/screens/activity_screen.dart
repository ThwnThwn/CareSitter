import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_content.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_content.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_empty_state.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

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
                        _buildSectionHeader('Đang diễn ra'),
                        const SizedBox(height: AppSpacing.control),
                        ...active.map((b) => _buildActiveCard(b, context)),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),

                // ── Recent section ───────────────────────
                if (recent.isNotEmpty)
                  ActivityRecentContent(
                      buildSectionHeader: _buildSectionHeader,
                      recent: recent,
                      buildRecentRow: _buildRecentRow),

                if (active.isEmpty && recent.isEmpty)
                  FadeSlideStaggered(
                    index: 0,
                    child: _buildEmptyState(context),
                  ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFontSizes.s17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ── Active shift card (nổi bật, full card) ──────────────────
  Widget _buildActiveCard(BookingModel booking, BuildContext context) =>
      ActivityActiveCard(booking: booking);

  // ── Recent booking row (Grab style) ─────────────────────────
  Widget _buildRecentRow(BookingModel booking, BuildContext context) =>
      ActivityRecentRow(
          booking: booking,
          getStatusConfig: _getStatusConfig,
          formatCurrency: _formatCurrency);

  Widget _buildEmptyState(BuildContext context) => const ActivityEmptyState();

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return {
          'shortLabel': 'Đang diễn ra',
          'color': AppColors.primary,
          'bg': AppColors.primaryContainer,
        };
      case 'caregiver_en_route':
        return {
          'shortLabel': 'Đang đến',
          'color': AppColors.info,
          'bg': AppColors.infoLight,
        };
      case 'caregiver_accepted':
      case 'assigned':
        return {
          'shortLabel': 'Đã nhận ca',
          'color': AppColors.legacyInfo,
          'bg': AppColors.legacyInfoLight,
        };
      case 'checkout_pending_review':
        return {
          'shortLabel': 'Chờ xác nhận',
          'color': AppColors.purple,
          'bg': AppColors.purpleLight,
        };
      case 'disputed':
        return {
          'shortLabel': 'Đang xử lý',
          'color': AppColors.warning,
          'bg': AppColors.warningLight,
        };
      case 'confirmed':
        return {
          'shortLabel': 'Đã xác nhận',
          'color': AppColors.warning,
          'bg': AppColors.secondaryContainer,
        };
      case 'pending':
      case 'pending_payment':
      case 'draft':
        return {
          'shortLabel': 'Chờ xác nhận',
          'color': AppColors.textSecondary,
          'bg': AppColors.background,
        };
      case 'payment_reconciliation_pending':
        return {
          'shortLabel': 'Đang đối soát',
          'color': AppColors.blueDark,
          'bg': AppColors.infoLight,
        };
      case 'needs_manual_review':
        return {
          'shortLabel': 'Chờ kiểm tra',
          'color': AppColors.warning,
          'bg': AppColors.warningLight,
        };
      case 'completed':
        return {
          'shortLabel': 'Hoàn thành',
          'color': AppColors.legacyInfo,
          'bg': AppColors.legacyInfoLight,
        };
      case 'cancelled':
      case 'refunded':
        return {
          'shortLabel': 'Đã huỷ',
          'color': AppColors.legacyError,
          'bg': AppColors.legacyErrorLight,
        };
      case 'matching_failed':
        return {
          'shortLabel': 'Chưa ghép được',
          'color': AppColors.warning,
          'bg': AppColors.warningLight,
        };
      default:
        final formatted = status.replaceAll('_', ' ');
        return {
          'shortLabel': formatted.isEmpty
              ? 'Chi tiết ca'
              : formatted[0].toUpperCase() + formatted.substring(1),
          'color': AppColors.textSecondary,
          'bg': AppColors.surface,
        };
    }
  }

  String _formatCurrency(double amount) {
    return formatVnd(amount);
  }
}
