import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/catalog_service_filter.dart';
import 'package:flutter/material.dart';

class CatalogServiceTypeFilter extends StatelessWidget {
  const CatalogServiceTypeFilter({
    super.key,
    required this.services,
    required this.selected,
    required this.onSelected,
  });

  final List<ServiceModel> services;
  final CatalogServiceFilter selected;
  final ValueChanged<CatalogServiceFilter> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Lọc dịch vụ theo cách tính giá',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: CatalogServiceFilter.values
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: ValueKey('catalog-filter-${filter.name}'),
                      label: Text(
                        '${filter.label} ${_count(filter)}',
                        style: TextStyle(
                          color: selected == filter
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                          fontSize: AppFontSizes.s11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: selected == filter,
                      showCheckmark: false,
                      selectedColor: AppColors.primaryContainer,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: selected == filter
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      onSelected: (_) => onSelected(filter),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );

  int _count(CatalogServiceFilter filter) =>
      services.where(filter.matches).length;
}
