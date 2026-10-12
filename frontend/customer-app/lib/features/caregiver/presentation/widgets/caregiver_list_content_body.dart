import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/core/widgets/location_selector.dart';

class CaregiverListContentBody extends StatelessWidget {
  const CaregiverListContentBody({super.key, required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LocationSelector(
                  loading: ref.watch(caregiverSearchAddressProvider).isLoading,
                  failed: ref.watch(caregiverSearchAddressProvider).hasError,
                  selectedId:
                      ref.watch(caregiverSearchAddressProvider).valueOrNull?.id,
                  shortAddress: ref
                      .watch(caregiverSearchAddressProvider)
                      .valueOrNull
                      ?.shortAddress,
                  onRetry: () => ref.invalidate(addressStoreProvider),
                  onSelected: (id) => ref
                      .read(caregiverSearchAddressIdProvider.notifier)
                      .state = id)),
          const Text('Chưa tải được danh sách chăm sóc viên.'),
          TextButton(
              onPressed: () => ref.invalidate(nearbyCaregiversProvider),
              child: const Text('Thử lại')),
        ],
      ));
}
