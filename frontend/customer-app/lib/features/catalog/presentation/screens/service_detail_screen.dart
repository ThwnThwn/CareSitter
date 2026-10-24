import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_detail_content.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_detail_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceStoreProvider);
    final checklist = ref.watch(serviceChecklistProvider(serviceId));
    return services.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => ServiceDetailError(
        onRetry: () => ref.read(serviceStoreProvider.notifier).refresh(),
      ),
      data: (items) {
        final service = items.where((item) => item.id == serviceId).firstOrNull;
        if (service == null) return const ServiceDetailNotFound();
        return ServiceDetailContent(
          service: service,
          checklistItems: checklist.asData?.value ?? const [],
          checklistLoading: checklist.isLoading,
          checklistError:
              checklist.hasError ? 'Không tải được checklist.' : null,
          onRetryChecklist: () =>
              ref.invalidate(serviceChecklistProvider(serviceId)),
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.catalog),
          onShare: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã sẵn sàng để chia sẻ dịch vụ.'),
            ),
          ),
          onBook: () => context.push(
            AppRoutes.bookingNewWith(serviceId: service.id),
          ),
        );
      },
    );
  }
}
