import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import '../../../controllers/booking_wizard_state.dart';
import 'duration_chip.dart';
import 'duration_slider_card.dart';

class DurationSelector extends ConsumerWidget {
  const DurationSelector({super.key, required this.args});

  final BookingWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours =
        ref.watch(bookingWizardProvider(args).select((s) => s.duration));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _DurationHeader(),
      const SizedBox(height: AppSpacing.compact),
      _DurationPresets(
        selectedHours: hours,
        onChanged: (value) =>
            ref.read(bookingWizardProvider(args).notifier).setDuration(value),
      ),
      const SizedBox(height: AppSpacing.compact),
      DurationSliderCard(
        hours: hours,
        minH: BookingWizardController.minimumDurationHours.toDouble(),
        maxH: BookingWizardController.maximumDurationHours.toDouble(),
        service: ref.watch(wizardServiceProvider(args)),
        onChanged: (value) =>
            ref.read(bookingWizardProvider(args).notifier).setDuration(value),
      ),
    ]);
  }
}

class _DurationHeader extends StatelessWidget {
  const _DurationHeader();

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.compact,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            'Thời lượng ca chăm sóc',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'Tối thiểu ${BookingWizardController.minimumDurationHours} giờ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      );
}

class _DurationPresets extends StatelessWidget {
  const _DurationPresets({
    required this.selectedHours,
    required this.onChanged,
  });

  final int selectedHours;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final scaledText = MediaQuery.textScalerOf(context).scale(1);
          final columns =
              constraints.maxWidth < 360 || scaledText > 1.3 ? 2 : 4;
          const gap = AppSpacing.control;
          final itemWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final value in [2, 4, 8, 12])
                SizedBox(
                  width: itemWidth,
                  child: DurationChip(
                    hours: value,
                    selected: selectedHours == value,
                    onTap: () => onChanged(value),
                  ),
                ),
            ],
          );
        },
      );
}
