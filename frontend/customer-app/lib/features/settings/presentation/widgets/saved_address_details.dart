import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_summary.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_delete_action.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_icon.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_verification_badge.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressDetails extends StatelessWidget {
  const SavedAddressDetails(
      {super.key,
      required this.selectionMode,
      required this.address,
      required this.isSelected,
      required this.iconFor,
      required this.buildAddressHeader,
      required this.isDefault,
      required this.callbackAction2,
      required this.isDeleting,
      required this.deletingAddressId,
      required this.deleteAddress});
  final bool selectionMode;
  final AddressModel address;
  final bool isSelected;
  final IconData Function(AddressModel) iconFor;
  final Widget Function(AddressModel, bool, {required bool isDefault})
      buildAddressHeader;
  final bool isDefault;
  final void Function() callbackAction2;
  final bool isDeleting;
  final String? deletingAddressId;
  final Future<void> Function(AddressModel) deleteAddress;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: selectionMode && address.isVerified
            ? () => Navigator.pop(context, address.id)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SavedAddressIcon(address: address, iconFor: iconFor),
              const SizedBox(width: AppSpacing.inset),
              SavedAddressSummary(
                  buildAddressHeader: buildAddressHeader,
                  address: address,
                  isSelected: isSelected,
                  isDefault: isDefault,
                  selectionMode: selectionMode,
                  callbackAction2: callbackAction2),
              const SizedBox(width: AppSpacing.sm),
              if (selectionMode)
                SavedAddressVerificationBadge(
                    isSelected: isSelected, address: address)
              else
                SavedAddressDeleteAction(
                    address: address,
                    isDeleting: isDeleting,
                    deletingAddressId: deletingAddressId,
                    deleteAddress: deleteAddress),
            ],
          ),
        ),
      );
}
