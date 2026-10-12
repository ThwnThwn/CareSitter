import '../models/shift_status_presentation.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_show_extend_shift_sheet_selected_hours_format_currency_content.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_show_photo_preview_dialog_url_decoration.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_content.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_missing_state.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_app_bar.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_not_live_scaffold.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_map_section.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_en_route_banner.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_caregiver_card.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_needs_review_banner.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_progress_strip.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_task_list.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_task_row.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_family_note.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_info_row.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screeninfo_card.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_screen_trust_guarantee_card.dart';
import '../controllers/shift_tracking_controller.dart';
import '../controllers/shift_tracking_state.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const ShiftTrackingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ShiftTrackingScreen> createState() =>
      _ShiftTrackingScreenState();
}

class _ShiftTrackingScreenState extends ConsumerState<ShiftTrackingScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    Future.microtask(() {
      if (mounted) {
        ref
            .read(shiftTrackingControllerProvider(widget.bookingId).notifier)
            .setVisible(visible);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(shiftTrackingControllerProvider(widget.bookingId).notifier)
        .setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location =
        ref.watch(shiftTrackingControllerProvider(widget.bookingId));
    final bookingId = widget.bookingId;
    final matches =
        ref.watch(bookingStoreProvider).where((b) => b.id == bookingId);
    if (matches.isEmpty) {
      return const ShiftTrackingMissingState();
    }
    final bk = matches.first;
    final now = DateTime.now();
    final presentationStatus = bk.presentationStatusAt(now);

    // Màn theo dõi trực tiếp mở cho cả caregiver_en_route (caregiver đang di chuyển) và
    // in_progress / checkout_pending_review (ca đang diễn ra). Các trạng thái khác
    // vẫn hiển thị trang thông báo rõ ràng.
    const liveStatuses = {
      'caregiver_en_route',
      'in_progress',
      'checkout_pending_review'
    };
    if (!liveStatuses.contains(presentationStatus)) {
      return _buildNotLiveScaffold(context, bk, presentationStatus);
    }
    final doneCount = bk.tasks.where((t) => t.isCompleted).length;
    final skippedCount = bk.tasks.where((t) => t.isSkipped).length;
    final totalCount = bk.tasks.length;
    final progressPct = totalCount > 0 ? doneCount / totalCount : 0.0;

    return ShiftTrackingContent(
        buildFloatingAppBar: _buildFloatingAppBar,
        bk: bk,
        bookingId: bookingId,
        buildMapSection: _buildMapSection,
        location: location,
        buildEnRouteBanner: _buildEnRouteBanner,
        buildCaregiverCard: _buildCaregiverCard,
        buildNeedsReviewBanner: _buildNeedsReviewBanner,
        buildProgressStrip: _buildProgressStrip,
        doneCount: doneCount,
        totalCount: totalCount,
        progressPct: progressPct,
        skippedCount: skippedCount,
        buildTaskList: _buildTaskList,
        ref: ref,
        buildFamilyNote: _buildFamilyNote,
        buildInfoRow: _buildInfoRow,
        buildTrustGuaranteeCard: _buildTrustGuaranteeCard,
        action1: () => context.push('/bookings/$bookingId/timeline'),
        action2: () => _showExtendShiftSheet(context, bk));
  }

  // ── Fallback khi ca chưa/không còn ở trạng thái live ───────────────────────
  Widget _buildNotLiveScaffold(
    BuildContext context,
    BookingModel bk,
    String presentationStatus,
  ) =>
      ShiftTrackingScreenNotLiveScaffold(
          notLiveInfo: shiftNotLiveInfo,
          presentationStatus: presentationStatus,
          bk: bk);

  // ── Floating transparent AppBar ────────────────────────────────────────────
  PreferredSizeWidget _buildFloatingAppBar(BuildContext context) {
    return const ShiftTrackingAppBar();
  }

  // ── Map section ────────────────────────────────────────────────────────────
  Widget _buildMapSection(BookingModel bk, ShiftTrackingState location) =>
      ShiftTrackingScreenMapSection(
          bk: bk,
          buildMapUnavailable: _buildMapUnavailable,
          location: location);

  Widget _buildMapUnavailable() {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: const Text(
        'Chưa có tọa độ địa chỉ để hiển thị bản đồ.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  // ── Banner caregiver đang trên đường đến (en_route) ────────────────────────────────────────────
  Widget _buildEnRouteBanner(BookingModel bk, ShiftTrackingState location) =>
      ShiftTrackingScreenEnRouteBanner(bk: bk, location: location);

  // ── Caregiver card ─────────────────────────────────────────────────────────
  Widget _buildCaregiverCard(BuildContext context, BookingModel bk) =>
      ShiftTrackingScreenCaregiverCard(bk: bk);

  // ── Needs review banner ───────────────────────────────────────────────────
  Widget _buildNeedsReviewBanner(BuildContext context, BookingModel bk) =>
      ShiftTrackingScreenNeedsReviewBanner(bk: bk);

  // ── Progress strip ─────────────────────────────────────────────────────────
  Widget _buildProgressStrip(
    BookingModel bk,
    int done,
    int total,
    double pct, {
    int skippedCount = 0,
  }) =>
      ShiftTrackingScreenProgressStrip(
          bk: bk,
          done: done,
          total: total,
          skippedCount: skippedCount,
          pct: pct);

  // ── Task list (Read-only) ──────────────────────────────────────────────────
  Widget _buildTaskList(BuildContext context, WidgetRef ref, BookingModel bk) =>
      ShiftTrackingScreenTaskList(bk: bk, buildTaskRow: _buildTaskRow);

  Widget _buildTaskRow(
          CareTaskModel task, BookingModel bk, BuildContext context) =>
      ShiftTrackingScreenTaskRow(
          task: task,
          iconForTask: _iconForTask,
          showPhotoPreviewDialog: _showPhotoPreviewDialog);

  void _showPhotoPreviewDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: ShiftTrackingShowPhotoPreviewDialogUrlDecoration(
            url: url, action1: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  IconData _iconForTask(String title) {
    final t = title.toLowerCase();
    if (t.contains('check-in') || t.contains('check in')) {
      return Icons.login_rounded;
    }
    if (t.contains('ăn') || t.contains('bữa')) {
      return Icons.restaurant_menu_outlined;
    }
    if (t.contains('tắm') || t.contains('vệ sinh')) {
      return Icons.shower_outlined;
    }
    if (t.contains('tập') || t.contains('lý liệu') || t.contains('vận động')) {
      return Icons.directions_walk_outlined;
    }
    if (t.contains('ngủ') || t.contains('nghỉ')) {
      return Icons.bed_outlined;
    }
    if (t.contains('báo cáo') || t.contains('kết thúc')) {
      return Icons.assignment_turned_in_outlined;
    }
    if (t.contains('uống') || t.contains('dùng')) {
      return Icons.local_cafe_outlined;
    }
    return Icons.task_alt_outlined;
  }

  // ── Note supplied by the customer/family when creating the booking ─────────
  Widget _buildFamilyNote(String note) =>
      ShiftTrackingScreenFamilyNote(note: note);

  // ── Info chips ─────────────────────────────────────────────────────────────
  Widget _buildInfoRow(BookingModel bk) =>
      ShiftTrackingScreenInfoRow(infoCard: _infoCard, bk: bk);

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
  }) =>
      ShiftTrackingScreeninfoCard(icon: icon, label: label, value: value);

  Widget _buildTrustGuaranteeCard() =>
      const ShiftTrackingScreenTrustGuaranteeCard();

  void _showExtendShiftSheet(BuildContext context, BookingModel bk) {
    int selectedHours = 1;
    final bookedHours =
        bk.scheduledEnd.difference(bk.scheduledStart).inMinutes / 60;
    final effectiveHourlyRate =
        bookedHours > 0 ? bk.totalPrice / bookedHours : 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 32 + MediaQuery.of(ctx).viewInsets.bottom),
          child:
              ShiftTrackingShowExtendShiftSheetSelectedHoursFormatCurrencyContent(
                  selectedHours: selectedHours,
                  formatCurrency: _formatCurrency,
                  effectiveHourlyRate: effectiveHourlyRate,
                  callbackAction1: () => setSheetState(() => selectedHours--),
                  callbackAction2: () => setSheetState(() => selectedHours++),
                  callbackAction3: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '✅ Đã gửi yêu cầu gia hạn $selectedHours giờ đến người chăm sóc.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return formatVnd(amount);
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────────
