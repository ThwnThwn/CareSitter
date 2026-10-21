import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';

class BookingAddressCard extends StatelessWidget {
  const BookingAddressCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
  });

  final AddressModel item;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  String get title {
    if (item.label?.isNotEmpty ?? false) return item.label!;
    if (item.ward?.isNotEmpty ?? false) {
      return [item.ward, item.district]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(', ');
    }
    final full = item.fullAddress;
    return full.length > 40 ? '${full.substring(0, 40)}...' : full;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${isDefault ? 'Địa chỉ mặc định, ' : ''}$title, ${item.fullAddress}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.inset),
          decoration: _decoration(),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _AddressRadio(isSelected: isSelected),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: _AddressCopy(
                title: title,
                fullAddress: item.fullAddress,
                isDefault: isDefault,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  BoxDecoration _decoration() => BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.8)
              : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.shadow,
            blurRadius: isSelected ? 12 : 4,
            offset: Offset(0, isSelected ? 3 : 1),
          ),
        ],
      );
}

class _AddressRadio extends StatelessWidget {
  const _AddressRadio({required this.isSelected});
  final bool isSelected;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 5 : 1.5,
          ),
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
        ),
      );
}

class _AddressCopy extends StatelessWidget {
  const _AddressCopy({
    required this.title,
    required this.fullAddress,
    required this.isDefault,
  });
  final String title;
  final String fullAddress;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isDefault) ...[
          const SizedBox(width: AppSpacing.sm),
          const _DefaultBadge(),
        ],
      ]),
      const SizedBox(height: 3),
      Text(
        fullAddress,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'Mặc định',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}
