import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_details.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressSurface extends StatelessWidget {
  const SavedAddressSurface(
      {super.key,
      required this.selectionMode,
      required this.address,
      required this.isSelected,
      required this.iconFor,
      required this.buildAddressHeader,
      required this.isDefault,
      required this.isDeleting,
      required this.deletingAddressId,
      required this.deleteAddress,
      required this.callbackAction2});
  final bool selectionMode;
  final AddressModel address;
  final bool isSelected;
  final IconData Function(AddressModel) iconFor;
  final Widget Function(AddressModel, bool, {required bool isDefault})
      buildAddressHeader;
  final bool isDefault;
  final bool isDeleting;
  final String? deletingAddressId;
  final Future<void> Function(AddressModel) deleteAddress;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SavedAddressDetails(
            selectionMode: selectionMode,
            address: address,
            isSelected: isSelected,
            iconFor: iconFor,
            buildAddressHeader: buildAddressHeader,
            isDefault: isDefault,
            callbackAction2: callbackAction2,
            isDeleting: isDeleting,
            deletingAddressId: deletingAddressId,
            deleteAddress: deleteAddress),
      );
}
