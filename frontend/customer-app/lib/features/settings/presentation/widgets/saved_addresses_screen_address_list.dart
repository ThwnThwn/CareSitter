import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressesScreenAddressList extends StatelessWidget {
  const SavedAddressesScreenAddressList(
      {super.key,
      required this.selectionMode,
      required this.addresses,
      required this.buildEmptyState,
      required this.buildAddressCard,
      required this.defaultAddressId,
      required this.addNewAddress});
  final bool selectionMode;
  final List<AddressModel> addresses;
  final Widget Function() buildEmptyState;
  final Widget Function(AddressModel, String?) buildAddressCard;
  final String? defaultAddressId;
  final Future<void> Function() addNewAddress;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (selectionMode)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.compact),
            child: Text(
              'Chọn một địa chỉ đã xác minh để dùng cho lịch chăm sóc này.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s13),
            ),
          ),
        if (addresses.isEmpty) buildEmptyState(),
        ...addresses.map((a) => buildAddressCard(a, defaultAddressId)),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: addNewAddress,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Thêm địa chỉ mới'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
}
