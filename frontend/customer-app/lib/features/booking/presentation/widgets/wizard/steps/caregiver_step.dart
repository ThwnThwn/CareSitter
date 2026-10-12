import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';

class CaregiverStep extends ConsumerWidget {
  const CaregiverStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(bookingWizardProvider(args)
        .select((s) => (s.systemMatched, s.caregiverId)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Chọn chăm sóc viên',
          style: Theme.of(context).textTheme.titleMedium),
      SwitchListTile(
          title: const Text('Hệ thống tự ghép chăm sóc viên'),
          value: choice.$1,
          onChanged: (v) => ref
              .read(bookingWizardProvider(args).notifier)
              .setSystemMatched(v)),
      ref.watch(wizardCandidatesProvider(args)).when(
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(wizardCandidatesProvider(args)),
              child: const Text('Thử lại')),
          data: (items) {
            final online = items;
            return RadioGroup<String>(
                groupValue: choice.$2,
                onChanged: (id) => ref
                    .read(bookingWizardProvider(args).notifier)
                    .selectCaregiver(id),
                child: Column(children: [
                  if (online.isEmpty)
                    const Text(
                        'Chưa có chăm sóc viên trực tuyến. Bạn có thể để hệ thống tự ghép.'),
                  for (final c in online)
                    RadioListTile<String>(
                        value: c.id,
                        title: Text(c.displayName),
                        subtitle:
                            Text('${c.ratingAvg} ★ • ${c.skills.join(', ')}')),
                ]));
          }),
    ]);
  }
}
