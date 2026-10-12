import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/verified_address_field.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_address_form_data.dart';

class SavedAddressesAddressFormDialog extends ConsumerStatefulWidget {
  const SavedAddressesAddressFormDialog({super.key});

  @override
  ConsumerState<SavedAddressesAddressFormDialog> createState() =>
      _AddressFormDialogState();
}

class _AddressFormDialogState
    extends ConsumerState<SavedAddressesAddressFormDialog> {
  final _titleCtrl = TextEditingController();
  VerifiedAddressSelection? _selectedPlace;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.55)
        .clamp(300.0, 420.0)
        .toDouble();

    return AlertDialog(
      title: const Text(
        'Thêm địa chỉ mới',
        style:
            TextStyle(fontSize: AppFontSizes.s16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: double.infinity,
        height: contentHeight,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên địa điểm (Ví dụ: Nhà riêng, Công ty)',
                ),
              ),
              const SizedBox(height: AppSpacing.compact),
              VerifiedAddressField(
                onChanged: (value) => setState(() => _selectedPlace = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Bạn cần chọn một dòng gợi ý để CareSitter xác minh vị trí.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: _selectedPlace == null
              ? null
              : () {
                  final title = _titleCtrl.text.trim();
                  Navigator.pop(
                    context,
                    SavedAddressesAddressFormData(
                      title: title.isEmpty ? 'Địa chỉ chăm sóc' : title,
                      placeId: _selectedPlace!.details.placeId,
                      sessionToken: _selectedPlace!.sessionToken,
                    ),
                  );
                },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
