import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../common/wizard_card.dart';

class ServiceStep extends ConsumerWidget {
  const ServiceStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(bookingWizardProvider(args).select((s) => s.serviceId));
    return ref.watch(serviceStoreProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(serviceStoreProvider),
            child: const Text('Thử lại')),
        data: (items) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chọn dịch vụ chăm sóc',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              if (items.isEmpty) const Text('Chưa có dịch vụ khả dụng.'),
              for (final item in items)
                WizardCard(
                    selected: selected == item.id,
                    onTap: () => ref
                        .read(bookingWizardProvider(args).notifier)
                        .selectService(item.id),
                    child: Row(children: [
                      Text(item.icon),
                      const SizedBox(width: AppSpacing.compact),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.name,
                                style: Theme.of(context).textTheme.titleSmall),
                            if (item.description != null)
                              Text(item.description!),
                            Text('${formatVnd(item.pricePerHour)} / giờ'),
                          ])),
                      if (selected == item.id) const Icon(Icons.check_circle)
                    ])),
            ]));
  }
}
