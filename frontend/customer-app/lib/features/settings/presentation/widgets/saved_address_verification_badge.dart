import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressVerificationBadge extends StatelessWidget {
  const SavedAddressVerificationBadge(
      {super.key, required this.isSelected, required this.address});
  final bool isSelected;
  final AddressModel address;

  @override
  Widget build(BuildContext context) => Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected
            ? AppColors.primary
            : address.isVerified
                ? AppColors.textHint
                : AppColors.divider,
        size: 22,
      );
}
