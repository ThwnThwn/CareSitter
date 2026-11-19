import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/caregiver_avatar.dart';
import '../common/booking_promotion_field.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
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
    final accountAvatar = flow.forSelf
        ? ref.watch(profileStoreProvider.select((profile) => profile.avatarUrl))
        : null;
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
          _ConfirmRow(leading: Text(service.icon), text: service.name),
      ]),
      if (recipient != null)
        _ConfirmRecipient(
          recipient: recipient,
          forSelf: flow.forSelf,
          avatarUrl: accountAvatar ?? recipient.avatarPath,
        ),
      _ConfirmCard(title: 'Người chăm sóc', children: [
        if (caregiver != null)
          _ConfirmRow(
            leading: CaregiverAvatar(
                initials: caregiver.initials, seed: caregiver.id, radius: 17),
            text: caregiver.displayName,
          )
        else if (flow.systemMatched)
          const _ConfirmRow(
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.primary,
              child: Icon(Icons.person_search_outlined, size: 20),
            ),
            text: 'Hệ thống sẽ tìm người chăm sóc phù hợp',
          ),
      ]),
      _ConfirmCard(title: 'Thời gian', children: [
        if (flow.date != null)
          _ConfirmRow(
              leading: const Icon(Icons.calendar_today_outlined, size: 16),
              text: formatDate(flow.date!)),
        if (flow.startMinutes != null)
          _ConfirmRow(
              leading: const Icon(Icons.schedule_outlined, size: 16),
              text:
                  '${TimeOfDay(hour: flow.startMinutes! ~/ 60, minute: flow.startMinutes! % 60).format(context)} • ${flow.duration} giờ'),
        if (address != null)
          _ConfirmRow(
              leading: const Icon(Icons.place_outlined, size: 16),
              text: address.shortAddress),
      ]),
      const SizedBox(height: AppSpacing.tight),
      BookingPromotionField(
        key: ValueKey(args),
        args: args,
        estimatedAmount:
            service == null ? null : service.pricePerHour * flow.duration,
      ),
    ]);
  }
}

class _ConfirmRecipient extends StatelessWidget {
  const _ConfirmRecipient(
      {required this.recipient, required this.forSelf, this.avatarUrl});
  final BeneficiaryModel recipient;
  final bool forSelf;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => _ConfirmCard(
        title: 'Người được chăm sóc',
        children: [
          _ConfirmRow(
              leading: CaregiverAvatar(
                  initials: recipient.avatarInitial,
                  seed: recipient.name,
                  avatarUrl: avatarUrl,
                  radius: 17),
              text:
                  '${forSelf ? 'Tôi — ' : ''}${recipient.name} (${recipient.ageLabel})'),
          if (forSelf) ...[
            Text(recipient.careLevelLabel),
            if (recipient.condition.isNotEmpty) Text(recipient.condition),
            if (recipient.notes.isNotEmpty) Text(recipient.notes),
            for (final contact in recipient.emergencyContacts)
              Text('${contact.name}: ${contact.phone}'),
          ],
        ],
      );
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
  const _ConfirmRow({required this.leading, required this.text});
  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(children: [
        leading,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
      ]));
}
