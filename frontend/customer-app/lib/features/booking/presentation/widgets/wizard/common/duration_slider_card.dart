import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';

class DurationSliderCard extends StatelessWidget {
  const DurationSliderCard({
    super.key,
    required this.hours,
    required this.minH,
    required this.maxH,
    required this.service,
    required this.onChanged,
  });

  final int hours;
  final double minH;
  final double maxH;
  final ServiceModel? service;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final price = service == null
        ? null
        : formatVnd(service!.pricePerHour * hours, round: true);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.inset),
      child: Column(children: [
        _DurationValueHeader(hours: hours),
        const SizedBox(height: AppSpacing.compact),
        _DurationSlider(
          hours: hours,
          minH: minH,
          maxH: maxH,
          onChanged: onChanged,
        ),
        const _DurationTicks(),
        if (price != null) ...[
          const SizedBox(height: AppSpacing.compact),
          _EstimatedPrice(price: price),
        ],
      ]),
    );
  }
}

class _DurationValueHeader extends StatelessWidget {
  const _DurationValueHeader({required this.hours});

  final int hours;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.compact,
        runSpacing: AppSpacing.xs,
        children: [
          Text('Thời lượng tùy chỉnh:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  )),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(hours),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.compact, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text('$hours giờ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      )),
            ),
          ),
        ],
      );
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    required this.hours,
    required this.minH,
    required this.maxH,
    required this.onChanged,
  });

  final int hours;
  final double minH;
  final double maxH;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.divider,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primaryContainer,
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11, elevation: 3, pressedElevation: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        ),
        child: Slider(
          value: hours.toDouble().clamp(minH, maxH),
          min: minH,
          max: maxH,
          divisions: (maxH - minH).round(),
          label: '$hours giờ',
          onChanged: (value) => onChanged(value.round()),
        ),
      );
}

class _DurationTicks extends StatelessWidget {
  const _DurationTicks();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.control),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final tick in [2, 4, 6, 8, 10, 12])
              Text('$tick h',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textHint,
                      )),
          ],
        ),
      );
}

class _EstimatedPrice extends StatelessWidget {
  const _EstimatedPrice({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: AppSpacing.compact),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.compact,
          runSpacing: AppSpacing.xs,
          children: [
            Text('Giá dự kiến:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    )),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(price,
                  key: ValueKey(price),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ],
        ),
      );
}
