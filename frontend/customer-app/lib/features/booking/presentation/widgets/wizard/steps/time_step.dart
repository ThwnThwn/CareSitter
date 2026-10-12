import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../common/schedule_picker.dart';
import '../common/duration_selector.dart';
import '../common/booking_address_selector.dart';

class TimeStep extends ConsumerWidget {
  const TimeStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Chọn thời gian', style: Theme.of(context).textTheme.titleMedium),
        const Text('Chọn ngày và giờ bắt đầu ca chăm sóc'),
        const SizedBox(height: AppSpacing.section),
        SchedulePicker(args: args),
        const SizedBox(height: AppSpacing.lg),
        DurationSelector(args: args),
        const SizedBox(height: AppSpacing.lg),
        BookingAddressSelector(args: args),
      ]);
}
