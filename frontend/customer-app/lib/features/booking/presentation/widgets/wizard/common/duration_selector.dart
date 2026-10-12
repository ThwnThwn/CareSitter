import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/booking_wizard_selectors.dart';

class DurationSelector extends ConsumerWidget {
  const DurationSelector({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours =
        ref.watch(bookingWizardProvider(args).select((s) => s.duration));
    final service = ref.watch(wizardServiceProvider(args));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Thời lượng ca chăm sóc',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.compact),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final value in [2, 4, 8, 12])
          ChoiceChip(
              label: Text('$value giờ'),
              selected: hours == value,
              onSelected: (_) => ref
                  .read(bookingWizardProvider(args).notifier)
                  .setDuration(value))
      ]),
      const SizedBox(height: AppSpacing.compact),
      Text('Thời lượng tùy chỉnh: $hours giờ'),
      Slider(
          value: hours.toDouble(),
          min: BookingWizardController.minimumDurationHours.toDouble(),
          max: BookingWizardController.maximumDurationHours.toDouble(),
          divisions: BookingWizardController.maximumDurationHours -
              BookingWizardController.minimumDurationHours,
          label: '$hours giờ',
          onChanged: (v) => ref
              .read(bookingWizardProvider(args).notifier)
              .setDuration(v.round())),
      if (service != null)
        Text(
            'Giá dự kiến: ${formatVnd(service.pricePerHour * hours, round: true)}'),
    ]);
  }
}
