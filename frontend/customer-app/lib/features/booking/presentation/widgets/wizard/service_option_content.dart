import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/widgets/service_image.dart';
import 'package:caresitter_customer/features/booking/presentation/models/service_option_style.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';

class ServiceOptionContent extends StatelessWidget {
  const ServiceOptionContent({
    super.key,
    required this.service,
    required this.option,
    required this.selected,
    required this.transitionDuration,
  });

  final ServiceModel service;
  final ServiceOptionStyle option;
  final bool selected;
  final Duration transitionDuration;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 310;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServiceImage(
                code: service.code,
                imageUrl: service.imageUrl,
                width: compact ? 82 : 104,
                height: compact ? 112 : 132,
                fallbackBackground: option.iconBackground,
                fallbackForeground: option.iconForeground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ServiceSummary(
                  service: service,
                  option: option,
                  selected: selected,
                  transitionDuration: transitionDuration,
                ),
              ),
            ],
          );
        },
      );
}

class _ServiceSummary extends StatelessWidget {
  const _ServiceSummary({
    required this.service,
    required this.option,
    required this.selected,
    required this.transitionDuration,
  });

  final ServiceModel service;
  final ServiceOptionStyle option;
  final bool selected;
  final Duration transitionDuration;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ServiceTitle(option: option)),
              const SizedBox(width: AppSpacing.sm),
              _SelectionIndicator(
                selected: selected,
                duration: transitionDuration,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _ServicePrice(
            minimumPlanPrice: service.minimumPlanPrice,
            pricePerHour: service.pricePerHour,
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            'Thời lượng gợi ý: ${_formatDuration(service.defaultDurationMinutes)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (service.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              service.description!.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      );

  static String _formatDuration(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60} giờ';
    return '${minutes ~/ 60} giờ ${minutes % 60} phút';
  }
}

class _ServiceTitle extends StatelessWidget {
  const _ServiceTitle({required this.option});

  final ServiceOptionStyle option;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.tight,
        runSpacing: AppSpacing.micro,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            option.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (option.subtitle != null)
            Text(
              option.subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      );
}

class _ServicePrice extends StatelessWidget {
  const _ServicePrice({
    required this.minimumPlanPrice,
    required this.pricePerHour,
  });

  final int minimumPlanPrice;
  final double pricePerHour;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(
            minimumPlanPrice > 0
                ? formatVnd(minimumPlanPrice)
                : formatVnd(pricePerHour),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            minimumPlanPrice > 0 ? '/buổi' : '/giờ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
          border:
              selected ? null : Border.all(color: AppColors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration: duration == Duration.zero
              ? Duration.zero
              : const Duration(milliseconds: 120),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: selected
              ? const Icon(
                  Icons.check_rounded,
                  key: ValueKey('selected'),
                  size: 16,
                  color: Colors.white,
                )
              : const SizedBox(key: ValueKey('unselected')),
        ),
      );
}
