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
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => _AddressPickerButton(
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
          return _AddressPickerButton(
            onTap: () => _openSelector(context, ref),
            title: selected.displayLabel,
            subtitle: selected.fullAddress,
            icon: Icons.verified_outlined,
            color: AppColors.primary,
            selected: true,
          );
        }

        return _AddressPickerButton(
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

class _AddressPickerButton extends StatelessWidget {
  const _AddressPickerButton({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.selected = false,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      );
}
