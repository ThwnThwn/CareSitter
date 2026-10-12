import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressDeleteAction extends StatelessWidget {
  const SavedAddressDeleteAction(
      {super.key,
      required this.address,
      required this.isDeleting,
      required this.deletingAddressId,
      required this.deleteAddress});
  final AddressModel address;
  final bool isDeleting;
  final String? deletingAddressId;
  final Future<void> Function(AddressModel) deleteAddress;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Xóa ${address.displayLabel}',
        icon: isDeleting && deletingAddressId == address.id
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.delete_outline,
                color: AppColors.textHint,
                size: 20,
              ),
        onPressed:
            deletingAddressId != null ? null : () => deleteAddress(address),
      );
}
