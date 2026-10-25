import 'location_selector_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

class LocationSelector extends StatelessWidget {
  const LocationSelector(
      {super.key,
      required this.loading,
      required this.failed,
      this.selectedId,
      this.shortAddress,
      required this.onRetry,
      required this.onSelected});
  final bool loading, failed;
  final String? selectedId, shortAddress;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.compact),
      child: InkWell(
        key: const Key('caregiver-location-selector'),
        borderRadius: BorderRadius.circular(AppRadius.compact),
        onTap: loading
            ? null
            : () async {
                if (failed) {
                  onRetry();
                  return;
                }
                final route = AppRoutes.addressesSelect(
                  selectedId: selectedId,
                );
                final selected = await context.push<String>(route);
                if (!context.mounted || selected == null) return;
                onSelected(selected);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact, vertical: AppSpacing.compact),
          child: LocationSelectorContent(
              loading: loading,
              failed: failed,
              selectedId: selectedId,
              shortAddress: shortAddress),
        ),
      ),
    );
  }
}
