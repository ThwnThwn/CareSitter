import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressIcon extends StatelessWidget {
  const SavedAddressIcon({super.key, required this.address});
  final AddressModel address;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.control),
        decoration: BoxDecoration(
          color: address.isVerified
              ? AppColors.primaryContainer
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.compact),
        ),
        child: Icon(
          _iconFor(address),
          color: address.isVerified ? AppColors.primary : AppColors.textHint,
          size: 22,
        ),
      );
  IconData _iconFor(AddressModel address) {
    final label = address.displayLabel.toLowerCase();
    if (label.contains('nhà') || label.contains('nha')) {
      return Icons.home_outlined;
    }
    if (label.contains('văn phòng') ||
        label.contains('van phong') ||
        label.contains('công ty') ||
        label.contains('cong ty')) {
      return Icons.work_outline;
    }
    return Icons.location_on_outlined;
  }
}
