import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../common/booking_total_card.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import '../../../controllers/booking_wizard_state.dart';
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
      const Text('Xác nhận đặt lịch',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      const Text('Kiểm tra lại thông tin trước khi đặt',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: AppSpacing.md),
      _ConfirmCard(title: 'Dịch vụ', children: [
        if (service != null)
          _ConfirmRow(icon: service.icon, text: service.name),
      ]),
      _ConfirmCard(title: 'Người được chăm sóc', children: [
        if (recipient != null)
          _ConfirmRow(
              icon: '👤',
              text:
                  '${flow.forSelf ? 'Tôi — ' : ''}${recipient.name} (${recipient.ageLabel})'),
        if (flow.forSelf && recipient != null) ...[
          Text(recipient.careLevelLabel),
          if (recipient.condition.isNotEmpty) Text(recipient.condition),
          if (recipient.notes.isNotEmpty) Text(recipient.notes),
          for (final contact in recipient.emergencyContacts)
            Text('${contact.name}: ${contact.phone}'),
        ],
      ]),
      _ConfirmCard(title: 'Người chăm sóc', children: [
        if (caregiver != null)
          _ConfirmRow(
              icon: '👩',
              text:
                  '${caregiver.displayName}${flow.systemMatched ? ' • Hệ thống gợi ý' : ''}')
        else if (flow.systemMatched)
          const _ConfirmRow(
              icon: '🤖',
              text: 'Hệ thống sẽ tự ghép chăm sóc viên phù hợp nhất'),
      ]),
      _ConfirmCard(title: 'Thời gian', children: [
        if (flow.date != null)
          _ConfirmRow(icon: '📅', text: formatDate(flow.date!)),
        if (flow.startMinutes != null)
          _ConfirmRow(
              icon: '⏰',
              text:
                  '${TimeOfDay(hour: flow.startMinutes! ~/ 60, minute: flow.startMinutes! % 60).format(context)} • ${flow.duration} giờ'),
        if (address != null)
          _ConfirmRow(icon: '📍', text: address.shortAddress),
      ]),
      const SizedBox(height: AppSpacing.tight),
      BookingTotalCard(amount: service == null ? null : service.pricePerHour * flow.duration),
    ]);
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => WizardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ]));
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
      ]));
}
