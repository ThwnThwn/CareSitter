import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_detail_content.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_detail_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceStoreProvider);
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
        return ServiceDetailContent(service: service);
      },
    );
  }
}
