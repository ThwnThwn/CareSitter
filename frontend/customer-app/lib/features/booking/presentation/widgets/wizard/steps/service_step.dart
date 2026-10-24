import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../service_option_card.dart';

class ServiceStep extends ConsumerWidget {
  const ServiceStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(bookingWizardProvider(args).select((s) => s.serviceId));
    final services = ref.watch(serviceStoreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn dịch vụ cần đặt',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Chọn loại dịch vụ chăm sóc phù hợp với nhu cầu của gia đình bạn',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        services.when(
          loading: () => const _ServiceLoadingState(),
          error: (_, __) => _ServiceErrorState(
            onRetry: () => ref.invalidate(serviceStoreProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const _ServiceEmptyState();
            return Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  ServiceOptionCard(
                    service: items[index],
                    selected: selected == items[index].id,
                    onTap: () => ref
                        .read(bookingWizardProvider(args).notifier)
                        .selectService(items[index].id),
                  ),
                  if (index < items.length - 1)
                    const SizedBox(height: AppSpacing.compact),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ServiceLoadingState extends StatelessWidget {
  const _ServiceLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < 2 ? AppSpacing.compact : 0,
          ),
          child: Container(
            height: 118,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceErrorState extends StatelessWidget {
  const _ServiceErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          const Text('Không tải được danh sách dịch vụ.'),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _ServiceEmptyState extends StatelessWidget {
  const _ServiceEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Text(
          'Chưa có dịch vụ khả dụng.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
