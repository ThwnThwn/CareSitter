import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressIcon extends StatelessWidget {
  const SavedAddressIcon(
      {super.key, required this.address, required this.iconFor});
  final AddressModel address;
  final IconData Function(AddressModel) iconFor;

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
          iconFor(address),
          color: address.isVerified ? AppColors.primary : AppColors.textHint,
          size: 22,
        ),
      );
}
