import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import '../common/wizard_card.dart';

class ConfirmStep extends ConsumerWidget {
  const ConfirmStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingWizardProvider(args));
    final service = ref.watch(wizardServiceProvider(args));
    final recipient = ref.watch(wizardRecipientProvider(args));
    final caregiver = ref.watch(wizardCaregiverProvider(args));
    final address = ref
        .watch(addressStoreProvider)
        .valueOrNull
        ?.where((a) => a.id == flow.addressId)
        .firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Xác nhận đặt lịch', style: Theme.of(context).textTheme.titleMedium),
      const Text('Kiểm tra lại thông tin trước khi đặt'),
      const SizedBox(height: AppSpacing.md),
      WizardCard(
          child: ListTile(
              title: const Text('Dịch vụ'),
              subtitle: Text(service?.name ?? ''))),
      WizardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Người được chăm sóc'),
        if (recipient != null)
          Text(
              '${flow.forSelf ? 'Tôi — ' : ''}${recipient.name} (${recipient.ageLabel})'),
        if (flow.forSelf && recipient != null) ...[
          Text(recipient.careLevelLabel),
          Text(recipient.condition),
          Text(recipient.notes),
          for (final c in recipient.emergencyContacts)
            Text('${c.name}: ${c.phone}'),
        ],
      ])),
      WizardCard(
          child: ListTile(
              title: const Text('Người chăm sóc'),
              subtitle: Text(caregiver?.displayName ??
                  'Hệ thống sẽ tự ghép chăm sóc viên phù hợp nhất'))),
      WizardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Thời gian'),
        if (flow.date != null) Text(formatDate(flow.date!)),
        if (flow.startMinutes != null)
          Text(
              '${TimeOfDay(hour: flow.startMinutes! ~/ 60, minute: flow.startMinutes! % 60).format(context)} • ${flow.duration} giờ'),
        Text(address?.shortAddress ?? ''),
      ])),
      WizardCard(
          selected: true,
          child: Text(
              'Tổng giá trị booking: ${formatVnd((service?.pricePerHour ?? 0) * flow.duration, round: true)}',
              style: Theme.of(context).textTheme.titleMedium)),
    ]);
  }
}
