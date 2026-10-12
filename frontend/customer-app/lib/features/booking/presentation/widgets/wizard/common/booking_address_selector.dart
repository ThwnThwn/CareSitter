import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';

class BookingAddressSelector extends ConsumerWidget {
  const BookingAddressSelector({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(bookingWizardProvider(args).select((s) => s.addressId));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Địa chỉ chăm sóc', style: Theme.of(context).textTheme.titleMedium),
      ref.watch(addressStoreProvider).when(
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(addressStoreProvider),
              child: const Text('Thử lại')),
          data: (items) => RadioGroup<String>(
              groupValue: selected,
              onChanged: (id) {
                if (id != null) {
                  ref
                      .read(bookingWizardProvider(args).notifier)
                      .selectAddress(id);
                }
              },
              child: Column(children: [
                for (final item in items.where((a) => a.isVerified))
                  RadioListTile<String>(
                      value: item.id,
                      title: Text(item.shortAddress),
                      subtitle: Text(item.fullAddress)),
                if (!items.any((a) => a.isVerified))
                  const Text('Chọn địa chỉ đã xác minh để tiếp tục.'),
              ]))),
      TextButton.icon(
          onPressed: () async {
            await context.push('/settings/addresses');
            if (context.mounted) ref.invalidate(addressStoreProvider);
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Quản lý địa chỉ')),
    ]);
  }
}
