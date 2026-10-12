import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_screen_address_list.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_screen_address_card.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_screen_address_header.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_screen_error_state.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_screen_empty_state.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_address_form_dialog.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/saved_addresses_address_form_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (data == null) return;

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
            : const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: addressesAsync.when(
        loading: _buildLoadingState,
        error: (_, __) => _buildErrorState(),
        data: (addresses) => _buildAddressList(addresses, defaultAddressId),
      ),
    );
  }

  Widget _buildAddressList(
          List<AddressModel> addresses, String? defaultAddressId) =>
      SavedAddressesScreenAddressList(
          selectionMode: widget.selectionMode,
          addresses: addresses,
          buildEmptyState: _buildEmptyState,
          buildAddressCard: _buildAddressCard,
          defaultAddressId: defaultAddressId,
          addNewAddress: _addNewAddress);

  Widget _buildAddressCard(AddressModel address, String? defaultAddressId) =>
      SavedAddressesScreenAddressCard(
          defaultAddressId: defaultAddressId,
          address: address,
          selectionMode: widget.selectionMode,
          selectedAddressId: widget.selectedAddressId,
          iconFor: _iconFor,
          buildAddressHeader: _buildAddressHeader,
          setAsDefault: _setAsDefault,
          isDeleting: _isDeleting,
          deletingAddressId: _deletingAddressId,
          deleteAddress: _deleteAddress);

  Widget _buildAddressHeader(
    AddressModel address,
    bool isSelected, {
    required bool isDefault,
  }) =>
      SavedAddressesScreenAddressHeader(
          address: address, isSelected: isSelected, isDefault: isDefault);

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

  Widget _buildErrorState() =>
      SavedAddressesScreenErrorState(ref: ref, addNewAddress: _addNewAddress);

  Widget _buildEmptyState() => const SavedAddressesScreenEmptyState();

  IconData _iconFor(AddressModel address) {
    final label = address.displayLabel.toLowerCase();
    if (label.contains('nhà') || label.contains('nha')) {
      return Icons.home_outlined;
    }
    if (label.contains('văn phòng') ||
        label.contains('van phong') ||
        label.contains('công ty') ||
        label.contains('cong ty')) {
      return Icons.work_outline;
    }
    return Icons.location_on_outlined;
  }
}
