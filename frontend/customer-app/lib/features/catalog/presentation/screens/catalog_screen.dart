import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_services_async_filtered_layout.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_screen_search_bar.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_screen_banner.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_screen_service_card.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<ServiceModel> _filtered(List<ServiceModel> services) {
    if (_searchQuery.isEmpty) return services;
    final q = _searchQuery.toLowerCase();
    return services
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.description?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(serviceStoreProvider);

    return CatalogServicesAsyncFilteredLayout(
        buildSearchBar: _buildSearchBar,
        buildBanner: _buildBanner,
        servicesAsync: servicesAsync,
        filtered: _filtered,
        buildServiceCard: _buildServiceCard);
  }

  // ── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => CatalogScreenSearchBar(
      searchCtrl: _searchCtrl,
      onChanged: (value) => setState(() => _searchQuery = value),
      searchQuery: _searchQuery);

  // ── Banner ────────────────────────────────────────────────────────────────
  Widget _buildBanner() => const CatalogScreenBanner();

  // ── Service Card ──────────────────────────────────────────────────────────
  static const _iconColors = [
    (bg: AppColors.softGreen, fg: AppColors.primary),
    (bg: AppColors.softOrange, fg: AppColors.brownOrange),
    (bg: AppColors.softBlue, fg: AppColors.brightBlue),
    (bg: AppColors.pinkLight, fg: AppColors.pinkDark),
    (bg: AppColors.limeLight, fg: AppColors.limeDark),
    (bg: AppColors.violetLight, fg: AppColors.violetDark),
  ];

  Widget _buildServiceCard(
          ServiceModel service, int index, BuildContext context) =>
      CatalogScreenServiceCard(
          colors: _iconColors[index % _iconColors.length],
          service: service,
          formatVnd: _formatVnd);

  String _formatVnd(int amount) {
    return formatVnd(amount, zeroLabel: 'Liên hệ');
  }
}
