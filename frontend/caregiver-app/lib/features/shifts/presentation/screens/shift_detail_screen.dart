import 'package:caregiver_app/features/shifts/presentation/models/shift_detail_status.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_body.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_app_bar.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_missing_app_bar.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_safety_content.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_status_banner.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_earnings_card.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_schedule_info.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_recipient_card.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_location_card.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_map_preview.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_map_unavailable.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_checklist_card.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_safety_item.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_start_travel_action.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_offer_actions.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_en_route_banner.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_active_action.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_completed_card.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class ShiftDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ShiftDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends ConsumerState<ShiftDetailScreen> {
  bool _safetyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(shiftsProvider);

    ShiftModel? booking;
    for (final b in shifts) {
      if (b.id == widget.id) {
        booking = b;
        break;
      }
    }
    if (booking == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        appBar: ShiftDetailMissingAppBar(),
        body: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy ca làm việc',
          message: 'Ca này có thể đã bị huỷ hoặc không còn tồn tại.',
        ),
      );
    }

    final beneficiary = _resolveBeneficiary(booking);
    final isPending = booking.canAccept;
    final isUpcoming = booking.canStartEnRoute;
    final isEnRoute = booking.canCheckIn;
    final isInProgress = booking.status == 'in_progress';
    final isCompleted = booking.status == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ShiftDetailAppBar(callbackAction1: () {}),
      body: Column(
        children: [
          ShiftDetailBody(
              buildStatusBanner: _buildStatusBanner,
              booking: booking,
              buildEarningsSummaryCard: _buildEarningsSummaryCard,
              buildScheduleInfo: _buildScheduleInfo,
              buildSectionHeader: _buildSectionHeader,
              buildCareRecipientCard: _buildCareRecipientCard,
              beneficiary: beneficiary,
              buildLocationCard: _buildLocationCard,
              buildChecklistCard: _buildChecklistCard,
              buildSafetyGuidelinesCard: _buildSafetyGuidelinesCard,
              isPending: isPending,
              buildAcceptRejectButtons: _buildAcceptRejectButtons,
              ref: ref,
              isEnRoute: isEnRoute,
              buildEnRouteBanner: _buildEnRouteBanner,
              isInProgress: isInProgress,
              buildGoToActiveShiftButton: _buildGoToActiveShiftButton,
              isCompleted: isCompleted,
              buildCompletedShiftCard: _buildCompletedShiftCard),
          if (isUpcoming) _buildStickyBottomBar(context, ref, booking),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  ShiftBeneficiaryModel _resolveBeneficiary(ShiftModel booking) {
    final name = booking.beneficiaryName.trim().isNotEmpty
        ? booking.beneficiaryName.trim()
        : 'Người thân';
    final initial = _getInitial(name);
    final age = booking.beneficiaryAge ?? 0;
    final relation = booking.beneficiaryRelationship?.isNotEmpty == true
        ? booking.beneficiaryRelationship!
        : 'Chưa cập nhật';
    final condition = booking.beneficiaryCondition?.isNotEmpty == true
        ? booking.beneficiaryCondition!
        : (booking.customerNote?.isNotEmpty == true
            ? booking.customerNote!
            : 'Chưa có thông tin');
    final notes = booking.beneficiaryNotes?.isNotEmpty == true
        ? booking.beneficiaryNotes!
        : (booking.customerNote?.isNotEmpty == true
            ? booking.customerNote!
            : 'Chưa có ghi chú');

    return ShiftBeneficiaryModel(
      id: booking.beneficiaryId ?? 'b_${booking.id}',
      name: name,
      age: age,
      relation: relation,
      avatarInitial: initial,
      condition: condition,
      careLevel: 'Chưa cập nhật',
      notes: notes,
    );
  }

  String _getInitial(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'N';
    return parts.first.substring(0, 1).toUpperCase();
  }

  // ─── UI Builders ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner(ShiftModel booking) => ShiftDetailStatusBanner(
      getStatusInfo: shiftDetailStatusInfo, booking: booking);

  Widget _buildEarningsSummaryCard(ShiftModel booking) =>
      ShiftDetailEarningsCard(booking: booking);

  Widget _buildScheduleInfo(ShiftModel booking) =>
      ShiftDetailScheduleInfo(booking: booking);

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: AppFontSizes.s16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
    );
  }

  Widget _buildCareRecipientCard(
          ShiftBeneficiaryModel beneficiary, ShiftModel booking) =>
      ShiftDetailRecipientCard(booking: booking, beneficiary: beneficiary);

  Widget _buildLocationCard(BuildContext context, ShiftModel booking) =>
      ShiftDetailLocationCard(
          destinationFor: _destinationFor,
          booking: booking,
          buildMapUnavailablePreview: _buildMapUnavailablePreview,
          buildMapPreview: _buildMapPreview,
          openMap: _openMap);

  LatLng? _destinationFor(ShiftModel booking) {
    final latitude = booking.addressLatitude;
    final longitude = booking.addressLongitude;
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  void _openMap(BuildContext context, ShiftModel booking) {
    context.push('/shifts/${booking.id}/map', extra: {
      'beneficiaryName': booking.beneficiaryName,
      'address': booking.address,
      'addressLatitude': booking.addressLatitude,
      'addressLongitude': booking.addressLongitude,
    });
  }

  Widget _buildMapPreview(
    BuildContext context,
    ShiftModel booking,
    LatLng destination,
  ) =>
      ShiftDetailMapPreview(
          ref: ref,
          destination: destination,
          openMap: _openMap,
          booking: booking);

  Widget _buildMapUnavailablePreview() => const ShiftDetailMapUnavailable();

  Widget _buildChecklistCard(
          ShiftModel booking, ShiftBeneficiaryModel beneficiary) =>
      ShiftDetailChecklistCard(booking: booking, beneficiary: beneficiary);

  Widget _buildSafetyGuidelinesCard(ShiftBeneficiaryModel beneficiary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ShiftSafetyContent(
          safetyExpanded: _safetyExpanded,
          safetyItem: _safetyItem,
          callbackAction1: () =>
              setState(() => _safetyExpanded = !_safetyExpanded)),
    );
  }

  Widget _safetyItem(String text) => ShiftSafetyItem(text: text);

  Widget _buildStickyBottomBar(
          BuildContext context, WidgetRef ref, ShiftModel booking) =>
      ShiftDetailStartTravelAction(ref: ref, booking: booking);

  // ─── Status-specific action widgets ───────────────────────────────────────

  Widget _buildAcceptRejectButtons(
          BuildContext context, WidgetRef ref, String bookingId) =>
      ShiftDetailOfferActions(ref: ref, bookingId: bookingId);

  Widget _buildEnRouteBanner(
          BuildContext context, WidgetRef ref, ShiftModel booking) =>
      ShiftDetailEnRouteBanner(ref: ref, booking: booking);

  Widget _buildGoToActiveShiftButton(BuildContext context, String bookingId) =>
      ShiftDetailActiveAction(bookingId: bookingId);

  Widget _buildCompletedShiftCard(ShiftModel booking) =>
      ShiftDetailCompletedCard(booking: booking);
}
