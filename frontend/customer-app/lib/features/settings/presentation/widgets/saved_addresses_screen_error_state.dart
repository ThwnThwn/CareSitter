import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressesScreenErrorState extends StatelessWidget {
  const SavedAddressesScreenErrorState(
      {super.key, required this.ref, required this.addNewAddress});
  final WidgetRef ref;
  final Future<void> Function() addNewAddress;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.inset),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  color: AppColors.error, size: 20),
              const SizedBox(width: AppSpacing.control),
              const Expanded(
                child: Text(
                  'Không tải được danh sách địa chỉ.',
                  style: TextStyle(
                      color: AppColors.error, fontSize: AppFontSizes.s13),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(addressStoreProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: addNewAddress,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Thêm địa chỉ mới'),
        ),
      ],
    );
  }
}
