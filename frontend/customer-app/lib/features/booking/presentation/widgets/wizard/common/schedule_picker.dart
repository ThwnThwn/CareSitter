import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import 'wizard_card.dart';

class SchedulePicker extends ConsumerWidget {
  const SchedulePicker({super.key, required this.args});
  final BookingWizardArgs args;
  Future<void> _date(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(bookingWizardProvider(args)).date;
    final now = DateTime.now();
    final value = await showDatePicker(
        context: context,
        initialDate: selected ?? now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 90)));
    if (context.mounted && value != null) {
      ref.read(bookingWizardProvider(args).notifier).selectDate(value);
    }
  }

  Future<void> _time(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(bookingWizardProvider(args)).startMinutes ?? 480;
    final value = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: selected ~/ 60, minute: selected % 60));
    if (context.mounted && value != null) {
      ref
          .read(bookingWizardProvider(args).notifier)
          .selectTime(value.hour * 60 + value.minute);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
        bookingWizardProvider(args).select((s) => (s.date, s.startMinutes)));
    final date = choice.$1, minutes = choice.$2;
    return Column(children: [
      WizardCard(
          onTap: () => _date(context, ref),
          selected: date != null,
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
                child: Text(date == null ? 'Chọn ngày' : formatDate(date))),
            const Icon(Icons.chevron_right)
          ])),
      WizardCard(
          onTap: date == null ? null : () => _time(context, ref),
          selected: minutes != null,
          child: Row(children: [
            const Icon(Icons.access_time_rounded),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
                child: Text(minutes == null
                    ? (date == null ? 'Chọn ngày trước' : 'Chọn giờ bắt đầu')
                    : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)
                        .format(context))),
            const Icon(Icons.chevron_right)
          ])),
      if (date != null &&
          minutes != null &&
          !ref.watch(wizardScheduleValidProvider(args)))
        const Text('Thời gian bắt đầu phải sau hiện tại ít nhất 30 phút.'),
    ]);
  }
}
