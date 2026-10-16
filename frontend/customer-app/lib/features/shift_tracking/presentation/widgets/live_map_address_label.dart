import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LiveMapAddressLabel extends StatelessWidget {
  const LiveMapAddressLabel({super.key, required this.routeAddressLabel});
  final String routeAddressLabel;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(AppSpacing.compact),
        child: Row(children: [
          const Icon(Icons.location_on_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(routeAddressLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s12,
                      height: 1.4))),
        ]),
      );
}
