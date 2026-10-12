import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/self_recipient_controller.dart';
import '../../self_recipient_form.dart';
import '../common/saved_self_recipient.dart';

class SelfRecipientStep extends ConsumerWidget {
  const SelfRecipientStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(selfRecipientProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => TextButton(
              onPressed: () => ref.read(selfRecipientProvider.notifier).load(),
              child: const Text('Thử lại')),
          data: (selected) => selected.kind != SelfRecipientKind.draft
              ? SavedSelfRecipient(args: args, selected: selected)
              : Column(children: [
                  SelfRecipientForm(
                      initial: selected.profile,
                      onDateValidityChanged: (value) => ref
                          .read(bookingWizardProvider(args).notifier)
                          .setDateValidity(value),
                      onChanged: (value) => ref
                          .read(selfRecipientProvider.notifier)
                          .updateDraft(value)),
                  ExpansionTile(
                      title: const Text('Dùng hồ sơ đã có của tôi'),
                      children: [
                        ref.watch(bookingRecipientsProvider).when(
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) => TextButton(
                                onPressed: () =>
                                    ref.invalidate(bookingRecipientsProvider),
                                child: const Text('Thử lại')),
                            data: (items) => Column(children: [
                                  if (items.where((b) => !b.isSelf).isEmpty)
                                    const ListTile(
                                        title: Text('Chưa có hồ sơ để chọn.')),
                                  for (final item
                                      in items.where((b) => !b.isSelf))
                                    ListTile(
                                        title: Text(item.name),
                                        subtitle: Text(
                                            '${item.ageLabel} • ${item.relation}'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => ref
                                            .read(bookingWizardProvider(args)
                                                .notifier)
                                            .selectLink(item)),
                                ])),
                      ]),
                ]));
}
