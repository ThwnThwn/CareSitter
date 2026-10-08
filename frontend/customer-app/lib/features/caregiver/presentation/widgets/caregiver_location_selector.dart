import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';

class CaregiverLocationSelector extends ConsumerWidget {
  const CaregiverLocationSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(caregiverSearchAddressProvider);
    final address = location.valueOrNull;
    final loading = location.isLoading;
    final failed = location.hasError;
    return Material(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: const Key('caregiver-location-selector'),
        borderRadius: BorderRadius.circular(10),
        onTap: loading
            ? null
            : () async {
                if (failed) {
                  ref.invalidate(addressStoreProvider);
                  return;
                }
                final route =
                    Uri(path: '/settings/addresses', queryParameters: {
                  'select': '1',
                  if (address != null) 'selected': address.id,
                });
                final selected = await context.push<String>(route.toString());
                if (!context.mounted || selected == null) return;
                ref.read(caregiverSearchAddressIdProvider.notifier).state =
                    selected;
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            const Icon(Icons.location_on_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    loading
                        ? 'Đang tải địa chỉ...'
                        : failed
                            ? 'Chưa tải được địa chỉ'
                            : address == null
                                ? 'Chọn địa chỉ chăm sóc'
                                : 'Địa chỉ chăm sóc',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (!loading && !failed) ...[
                  const SizedBox(height: 3),
                  Text(
                      address?.fullAddress ??
                          'Chọn địa chỉ có tọa độ để tìm người ở gần.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4)),
                ],
              ],
            )),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text(
                  failed
                      ? 'Thử lại'
                      : address == null
                          ? 'Chọn'
                          : 'Đổi',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
