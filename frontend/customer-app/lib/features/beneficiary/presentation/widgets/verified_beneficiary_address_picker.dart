import 'package:caresitter_customer/features/beneficiary/presentation/widgets/verified_beneficiary_address_picker_address_picker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

/// Chọn địa chỉ đã được xác minh từ cùng nguồn với luồng đặt lịch.
class VerifiedBeneficiaryAddressPicker extends ConsumerWidget {
  const VerifiedBeneficiaryAddressPicker({
    super.key,
    required this.selectedAddressId,
    required this.onChanged,
  });

  final String? selectedAddressId;
  final ValueChanged<AddressModel> onChanged;

  Future<void> _openSelector(BuildContext context, WidgetRef ref) async {
    final selectedParam = selectedAddressId == null
        ? ''
        : '&selected=${Uri.encodeComponent(selectedAddressId!)}';
    final selectedId = await context
        .push<String>('/settings/addresses?select=1$selectedParam');
    if (!context.mounted || selectedId == null || selectedId.isEmpty) return;

    final addresses = await ref.refresh(addressStoreProvider.future);
    if (!context.mounted) return;
    AddressModel? selected;
    for (final address in addresses) {
      if (address.id == selectedId) {
        selected = address;
        break;
      }
    }
    if (selected == null || !selected.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn một địa chỉ đã được xác minh.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressStoreProvider);
    return addresses.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.compact),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => VerifiedBeneficiaryAddressPickerAddressPickerButton(
        onTap: () => _openSelector(context, ref),
        title: 'Không tải được danh sách địa chỉ',
        subtitle: 'Chạm để thử lại hoặc chọn một địa chỉ khác.',
        icon: Icons.location_off_outlined,
        color: AppColors.error,
      ),
      data: (items) {
        AddressModel? selected;
        for (final address in items) {
          if (address.id == selectedAddressId) {
            selected = address;
            break;
          }
        }

        if (selected != null && selected.isVerified) {
          return VerifiedBeneficiaryAddressPickerAddressPickerButton(
            onTap: () => _openSelector(context, ref),
            title: selected.displayLabel,
            subtitle: selected.fullAddress,
            icon: Icons.verified_outlined,
            color: AppColors.primary,
            selected: true,
          );
        }

        return VerifiedBeneficiaryAddressPickerAddressPickerButton(
          onTap: () => _openSelector(context, ref),
          title: 'Chọn địa chỉ đã xác minh',
          subtitle: items.any((address) => address.isVerified)
              ? 'Dùng địa chỉ đã lưu để đặt lịch chính xác.'
              : 'Thêm địa chỉ từ danh sách gợi ý để xác minh vị trí.',
          icon: Icons.location_on_outlined,
          color: selectedAddressId == null
              ? AppColors.textSecondary
              : AppColors.warning,
        );
      },
    );
  }
}
