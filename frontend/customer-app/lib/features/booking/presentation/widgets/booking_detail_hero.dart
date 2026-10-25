import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';
import 'package:flutter/material.dart';

class BookingDetailHero extends StatelessWidget {
  const BookingDetailHero({
    super.key,
    required this.booking,
    required this.statusConfig,
  });

  final BookingModel booking;
  final BookingStatusPresentation statusConfig;

  @override
  Widget build(BuildContext context) {
    final serviceName = booking.serviceName ?? 'Dịch vụ hỗ trợ tại nhà';
    final beneficiaryName = booking.beneficiaryName ?? 'người thân';

    return Container(
      key: const Key('booking-detail-hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.comfortable),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              const _HeroBadge(
                icon: Icons.volunteer_activism_outlined,
                label: 'Hỗ trợ phi y tế tại nhà',
                foreground: AppColors.primary,
                background: AppColors.primaryContainer,
              ),
              _HeroBadge(
                icon: Icons.circle,
                label: statusConfig.label,
                foreground: statusConfig.color,
                background: statusConfig.backgroundColor,
                compactIcon: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.inset),
          Text(
            serviceName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.tight),
          Text(
            'Lịch hỗ trợ dành cho $beneficiaryName, với thời gian và phạm vi '
            'công việc đã được gia đình xác nhận.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _HeroMeta(
                icon: Icons.calendar_today_outlined,
                label: booking.date,
              ),
              _HeroMeta(
                icon: Icons.schedule_outlined,
                label: '${booking.time} • ${booking.duration}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.compactIcon = false,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final bool compactIcon;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 70;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.control,
        vertical: AppSpacing.tight,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compactIcon ? 8 : 15, color: foreground),
          const SizedBox(width: AppSpacing.tight),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 72;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 36),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.control,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.compact),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: AppSpacing.tight),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
