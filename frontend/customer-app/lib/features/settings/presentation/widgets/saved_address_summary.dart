import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_default_action.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_address_verification_notice.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressSummary extends StatelessWidget {
  const SavedAddressSummary(
      {super.key,
      required this.buildAddressHeader,
      required this.address,
      required this.isSelected,
      required this.isDefault,
      required this.selectionMode,
      required this.callbackAction2});
  final Widget Function(AddressModel, bool, {required bool isDefault})
      buildAddressHeader;
  final AddressModel address;
  final bool isSelected;
  final bool isDefault;
  final bool selectionMode;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildAddressHeader(address, isSelected, isDefault: isDefault),
            const SizedBox(height: AppSpacing.tight),
            Text(
              address.fullAddress,
              style: TextStyle(
                color: address.isVerified
                    ? AppColors.textSecondary
                    : AppColors.textHint,
                fontSize: AppFontSizes.s13,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!address.isVerified) const SavedAddressVerificationNotice(),
            if (!selectionMode && !isDefault && address.isVerified)
              SavedAddressDefaultAction(callbackAction1: callbackAction2),
          ],
        ),
      );
}
