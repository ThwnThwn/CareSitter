import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config_controller.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/service_model.dart';

class CatalogServiceResults extends ConsumerStatefulWidget {
  const CatalogServiceResults(
      {super.key, required this.services, required this.buildCard});
  final List<ServiceModel> services;
  final Widget Function(ServiceModel, int, BuildContext) buildCard;
  @override
  ConsumerState<CatalogServiceResults> createState() =>
      _CatalogServiceResultsState();
}

class _CatalogServiceResultsState extends ConsumerState<CatalogServiceResults> {
  int _page = 1;
  @override
  Widget build(BuildContext context) {
    final pageSize = ref.watch(runtimeConfigControllerProvider
        .select((s) => s.config.catalogPageSize));
    final pages = (widget.services.length / pageSize).ceil().clamp(1, 10000);
    final page = _page.clamp(1, pages);
    final start = (page - 1) * pageSize;
    final items = widget.services.skip(start).take(pageSize).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final entry in items.asMap().entries)
        widget.buildCard(entry.value, start + entry.key, context),
      if (pages > 1)
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                  onPressed:
                      page > 1 ? () => setState(() => _page = page - 1) : null,
                  child: const Text('Trang trước')),
              Text('Trang $page/$pages'),
              TextButton(
                  onPressed: page < pages
                      ? () => setState(() => _page = page + 1)
                      : null,
                  child: const Text('Trang sau')),
            ]),
    ]);
  }
}
