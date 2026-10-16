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
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator())),
        error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(serviceStoreProvider),
            child: const Text('Thử lại')),
        data: (items) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Chọn dịch vụ cần đặt',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Chọn loại dịch vụ chăm sóc phù hợp',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: AppSpacing.md),
              if (items.isEmpty) const Text('Chưa có dịch vụ khả dụng.'),
              for (final item in items)
                WizardCard(
                    selected: selected == item.id,
                    onTap: () => ref
                        .read(bookingWizardProvider(args).notifier)
                        .selectService(item.id),
                    child: Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                          alignment: Alignment.center,
                          child: Text(item.icon,
                              style: const TextStyle(fontSize: 22))),
                      const SizedBox(width: AppSpacing.compact),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(formatVnd(item.pricePerHour, suffix: 'đ/giờ'),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ])),
                      if (selected == item.id)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 22)
                    ])),
            ]));
  }
}
