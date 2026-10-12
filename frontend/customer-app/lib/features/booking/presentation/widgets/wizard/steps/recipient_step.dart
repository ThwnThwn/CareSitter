import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/self_recipient_controller.dart';
import 'self_recipient_step.dart';

class RecipientStep extends ConsumerWidget {
  const RecipientStep({super.key, required this.args});
  final BookingWizardArgs args;
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull?.userId;
    final id = await context.push<String>('/beneficiaries/create');
    if (!context.mounted ||
        ref.read(authStateProvider).valueOrNull?.userId != user ||
        id == null) {
      return;
    }
    ref.invalidate(bookingRecipientsProvider);
    try {
      final items = await ref.read(bookingRecipientsProvider.future);
      if (!context.mounted ||
          ref.read(authStateProvider).valueOrNull?.userId != user) {
        return;
      }
      final profile = items.where((b) => b.id == id && !b.isSelf).firstOrNull;
      if (profile != null) {
        ref.read(bookingWizardProvider(args).notifier).selectRecipient(profile);
      }
    } catch (_) {/* Provider hiển thị lỗi tải và thử lại. */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(bookingWizardProvider(args)
        .select((s) => (s.forSelf, s.beneficiaryId)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bạn đặt dịch vụ cho ai?',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.compact),
      SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Tôi'),
                icon: Icon(Icons.person_outline)),
            ButtonSegment(
                value: false,
                label: Text('Người thân'),
                icon: Icon(Icons.people_outline)),
          ],
          selected: {
            choice.$1
          },
          onSelectionChanged: (v) =>
              ref.read(bookingWizardProvider(args).notifier).forSelf(v.single)),
      const SizedBox(height: AppSpacing.section),
      if (choice.$1)
        SelfRecipientStep(args: args)
      else
        ref.watch(bookingRecipientsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(bookingRecipientsProvider),
                child: const Text('Thử lại')),
            data: (items) => Column(children: [
                  if (items.where((b) => !b.isSelf).isEmpty)
                    const Text(
                        'Chưa có hồ sơ người thân. Bạn có thể thêm ngay tại đây.'),
                  RadioGroup<String>(
                      groupValue: choice.$2,
                      onChanged: (id) {
                        final profile =
                            items.where((b) => b.id == id).firstOrNull;
                        if (profile != null) {
                          ref
                              .read(bookingWizardProvider(args).notifier)
                              .selectRecipient(profile);
                        }
                      },
                      child: Column(children: [
                        for (final b in items.where((b) => !b.isSelf))
                          RadioListTile<String>(
                              value: b.id,
                              title: Text(b.name),
                              subtitle: Text('${b.ageLabel} • ${b.relation}'))
                      ])),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Thêm người thân mới'),
                      onPressed: () => _add(context, ref)),
                ])),
    ]);
  }
}
