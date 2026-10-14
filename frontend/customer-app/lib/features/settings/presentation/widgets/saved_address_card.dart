import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'saved_address_icon.dart';
import 'saved_address_summary.dart';
import 'saved_address_verification_badge.dart';
import 'saved_address_delete_action.dart';

class SavedAddressCard extends StatelessWidget {
  const SavedAddressCard(
      {super.key,
      required this.address,
      required this.selectionMode,
      required this.isSelected,
      required this.isDefault,
      required this.deleteBlocked,
      required this.deleting,
      required this.onSetDefault,
      required this.onDelete});
  final AddressModel address;
  final bool selectionMode, isSelected, isDefault, deleteBlocked, deleting;
  final VoidCallback onSetDefault, onDelete;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.compact),
        child: Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
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
                      width: isSelected ? 1.5 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SavedAddressIcon(address: address),
                const SizedBox(width: AppSpacing.inset),
                SavedAddressSummary(
                    address: address,
                    isSelected: isSelected,
                    isDefault: isDefault,
                    selectionMode: selectionMode,
                    onSetDefault: onSetDefault),
                const SizedBox(width: AppSpacing.sm),
                if (selectionMode)
                  SavedAddressVerificationBadge(
                      isSelected: isSelected, address: address)
                else
                  SavedAddressDeleteAction(
                      label: address.displayLabel,
                      blocked: deleteBlocked,
                      deleting: deleting,
                      onDelete: onDelete),
              ]),
            ),
          ),
        ),
      );
}
