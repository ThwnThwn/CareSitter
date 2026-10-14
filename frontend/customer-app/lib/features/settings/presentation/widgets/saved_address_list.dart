import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/catalog/data/models/address_model.dart';
import 'saved_address_card.dart';
import 'saved_addresses_screen_empty_state.dart';

class SavedAddressList extends StatelessWidget {
  const SavedAddressList(
      {super.key,
      required this.selectionMode,
      required this.addresses,
      required this.defaultAddressId,
      required this.selectedAddressId,
      required this.deletingAddressId,
      required this.isDeleting,
      required this.onAddAddress,
      required this.onSetDefault,
      required this.onDelete});
  final bool selectionMode, isDeleting;
  final List<AddressModel> addresses;
  final String? defaultAddressId, selectedAddressId, deletingAddressId;
  final VoidCallback onAddAddress;
  final ValueChanged<AddressModel> onSetDefault, onDelete;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (selectionMode)
            const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.compact),
                child: Text(
                    'Chọn một địa chỉ đã xác minh để dùng cho lịch chăm sóc này.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSizes.s13))),
          if (addresses.isEmpty) const SavedAddressesScreenEmptyState(),
          for (final address in addresses)
            SavedAddressCard(
                address: address,
                selectionMode: selectionMode,
                isSelected: address.id == selectedAddressId,
                isDefault: address.id == defaultAddressId,
                deleteBlocked: deletingAddressId != null,
                deleting: isDeleting && deletingAddressId == address.id,
                onSetDefault: () => onSetDefault(address),
                onDelete: () => onDelete(address)),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
              onPressed: onAddAddress,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Thêm địa chỉ mới'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50))),
        ],
      );
}
