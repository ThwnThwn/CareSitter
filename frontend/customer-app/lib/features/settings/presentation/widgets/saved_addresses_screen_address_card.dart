import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_surface.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressesScreenAddressCard extends StatelessWidget {
  const SavedAddressesScreenAddressCard(
      {super.key,
      required this.defaultAddressId,
      required this.address,
      required this.selectionMode,
      required this.selectedAddressId,
      required this.iconFor,
      required this.buildAddressHeader,
      required this.setAsDefault,
      required this.isDeleting,
      required this.deletingAddressId,
      required this.deleteAddress});
  final String? defaultAddressId;
  final AddressModel address;
  final bool selectionMode;
  final String? selectedAddressId;
  final IconData Function(AddressModel) iconFor;
  final Widget Function(AddressModel, bool, {required bool isDefault})
      buildAddressHeader;
  final Future<void> Function(AddressModel) setAsDefault;
  final bool isDeleting;
  final String? deletingAddressId;
  final Future<void> Function(AddressModel) deleteAddress;
  @override
  Widget build(BuildContext context) {
    final isDefault = defaultAddressId == address.id;
    final isSelected = selectedAddressId == address.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.compact),
      child: SavedAddressSurface(
          selectionMode: selectionMode,
          address: address,
          isSelected: isSelected,
          iconFor: iconFor,
          buildAddressHeader: buildAddressHeader,
          isDefault: isDefault,
          isDeleting: isDeleting,
          deletingAddressId: deletingAddressId,
          deleteAddress: deleteAddress,
          callbackAction2: () => setAsDefault(address)),
    );
  }
}
