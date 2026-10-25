import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/shift_status_style.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_recipient_status.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_time_location.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScheduleShiftCard extends StatelessWidget {
  const ScheduleShiftCard({super.key, required this.shift});

  final TimelineShift shift;

  @override
  Widget build(BuildContext context) {
    final style = ShiftStatusStyle.of(shift.status);
    final statusLabel =
        shift.status == 'pending' ? 'Chờ thực hiện' : style.label;

    return Semantics(
      button: true,
      label: 'Xem ca của ${shift.beneficiaryName}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: style.color.withValues(alpha: 0.16)),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          fit: StackFit.loose,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: AppSpacing.s5,
              child: ColoredBox(color: style.color),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openShift(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.control,
                    AppSpacing.compact,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScheduleShiftRecipientStatus(
                        shift: shift,
                        statusLabel: statusLabel,
                        statusColor: style.color,
                      ),
                      const SizedBox(height: AppSpacing.tight),
                      ScheduleShiftTimeLocation(shift: shift),
                      const SizedBox(height: AppSpacing.sm),
                      _ScheduleShiftFooter(
                        shift: shift,
                        statusColor: style.color,
                        onOpenShift: () => _openShift(context),
                        onOpenRoute: () => _openRoute(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openShift(BuildContext context) {
    final suffix = shift.status == 'in_progress' ? '/active' : '';
    context.push('/shifts/${shift.id}$suffix');
  }

  void _openRoute(BuildContext context) {
    context.push('/shifts/${shift.id}/map', extra: {
      'beneficiaryName': shift.beneficiaryName,
      'address': shift.address,
      'addressLatitude': shift.addressLatitude,
      'addressLongitude': shift.addressLongitude,
    });
  }
}

class _ScheduleShiftFooter extends StatelessWidget {
  const _ScheduleShiftFooter({
    required this.shift,
    required this.statusColor,
    required this.onOpenShift,
    required this.onOpenRoute,
  });

  final TimelineShift shift;
  final Color statusColor;
  final VoidCallback onOpenShift;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final action = _actionForStatus();
    return Row(
      children: [
        Expanded(
          child: Text(
            _helperLabel(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFontSizes.s10,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ScheduleActionButton(
          key: ValueKey('schedule-action-${shift.id}'),
          label: action.label,
          icon: action.icon,
          filled: action.filled,
          color: statusColor,
          onTap: action.route ? onOpenRoute : onOpenShift,
        ),
      ],
    );
  }

  ({String label, IconData icon, bool filled, bool route}) _actionForStatus() {
    if (shift.status == 'in_progress') {
      return (
        label: 'Vào ca',
        icon: Icons.arrow_forward_rounded,
        filled: true,
        route: false,
      );
    }
    if (shift.status == 'confirmed' || shift.status == 'caregiver_en_route') {
      return (
        label: 'Lộ trình',
        icon: Icons.navigation_rounded,
        filled: true,
        route: true,
      );
    }
    return (
      label: 'Xem chi tiết',
      icon: Icons.chevron_right_rounded,
      filled: false,
      route: false,
    );
  }

  String _helperLabel() {
    if (shift.status == 'in_progress') return 'Ca đang diễn ra';
    if (shift.status == 'caregiver_en_route') return 'Đang đến địa điểm';

    final start = shift.scheduledStart;
    if (start != null) {
      final minutes = start.difference(DateTime.now()).inMinutes;
      if (minutes > 0 && minutes < 60) return 'Bắt đầu sau $minutes phút';
      if (minutes >= 60 && minutes < 24 * 60) {
        return 'Bắt đầu sau ${minutes ~/ 60} giờ';
      }
    }
    return shift.status == 'pending'
        ? 'Đang chờ thực hiện'
        : shift.timeRangeLabel;
  }
}

class _ScheduleActionButton extends StatelessWidget {
  const _ScheduleActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: filled ? color : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.control),
            decoration: filled
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.border),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: filled ? Colors.white : AppColors.textPrimary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFontSizes.s10,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
