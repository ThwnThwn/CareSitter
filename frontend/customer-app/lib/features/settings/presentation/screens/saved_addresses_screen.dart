import '../widgets/saved_address_list.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_screen_error_state.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_address_form_dialog.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_address_form_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/core/widgets/confirm_action_dialog.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class SavedAddressesScreen extends ConsumerStatefulWidget {
  final bool selectionMode;
  final String? selectedAddressId;

  const SavedAddressesScreen({
    super.key,
    this.selectionMode = false,
    this.selectedAddressId,
  });

  @override
  ConsumerState<SavedAddressesScreen> createState() =>
      _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  String? _deletingAddressId;
  bool _isDeleting = false;

  Future<void> _addNewAddress() async {
    final data = await showDialog<SavedAddressesAddressFormData>(
      context: context,
      builder: (_) => const SavedAddressesAddressFormDialog(),
    );
    if (data == null || !mounted) return;

    try {
      final created = await ref.read(addressStoreProvider.notifier).addAddress(
            label: data.title,
            placeId: data.placeId,
            sessionToken: data.sessionToken,
          );

      if (!mounted) return;
      if (widget.selectionMode) {
        Navigator.pop(context, created.id);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm địa chỉ mới')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thêm được địa chỉ. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    if (_deletingAddressId != null) return;
    setState(() => _deletingAddressId = address.id);
    try {
      final confirmed = await showConfirmActionDialog(
        context,
        title: 'Xóa địa chỉ?',
        message: '“${address.displayLabel}” (${address.fullAddress}) '
            'sẽ được gỡ khỏi danh sách địa chỉ đã lưu.',
        confirmLabel: 'Xóa địa chỉ',
      );
      if (!confirmed || !mounted) return;
      setState(() => _isDeleting = true);

      await ref.read(addressStoreProvider.notifier).deleteAddress(address.id);
      if (!mounted) return;
      AppToast.success(context, 'Đã xóa địa chỉ');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        error is AppApiException
            ? error.message
            : 'Không thể xóa địa chỉ. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingAddressId = null;
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _setAsDefault(AddressModel address) async {
    try {
      await ref
          .read(addressStoreProvider.notifier)
          .setDefaultAddress(address.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đặt "${address.displayLabel}" làm mặc định'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressStoreProvider);
    final defaultAddressId = ref.watch(
      profileStoreProvider.select((p) => p.defaultAddressId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
            widget.selectionMode ? 'Chọn địa chỉ chăm sóc' : 'Địa chỉ đã lưu'),
        leading: widget.selectionMode
            ? BackButton(onPressed: () => Navigator.pop(context))
            : const AppBackButton(fallbackRoute: AppRoutes.settings),
      ),
      body: addressesAsync.when(
        loading: _buildLoadingState,
        error: (_, __) => SavedAddressesScreenErrorState(
            onRetry: () => ref.invalidate(addressStoreProvider),
            addNewAddress: _addNewAddress),
        data: (addresses) => SavedAddressList(
            selectionMode: widget.selectionMode,
            addresses: addresses,
            defaultAddressId: defaultAddressId,
            selectedAddressId: widget.selectedAddressId,
            deletingAddressId: _deletingAddressId,
            isDeleting: _isDeleting,
            onAddAddress: _addNewAddress,
            onSetDefault: _setAsDefault,
            onDelete: _deleteAddress),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}
