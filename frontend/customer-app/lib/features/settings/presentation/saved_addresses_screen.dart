import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../catalog/application/address_store.dart';
import '../../catalog/presentation/widgets/verified_address_field.dart';
import '../../settings/application/profile_store.dart';

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
  Future<void> _addNewAddress() async {
    final data = await showDialog<_AddressFormData>(
      context: context,
      builder: (_) => const _AddressFormDialog(),
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
    try {
      await ref.read(addressStoreProvider.notifier).deleteAddress(address.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá địa chỉ')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Địa chỉ đang được sử dụng hoặc không thể xoá.'),
          backgroundColor: AppColors.error,
        ),
      );
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
      List<AddressModel> addresses, String? defaultAddressId) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.selectionMode)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Chọn một địa chỉ đã xác minh để dùng cho lịch chăm sóc này.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        if (addresses.isEmpty) _buildEmptyState(),
        ...addresses.map((a) => _buildAddressCard(a, defaultAddressId)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _addNewAddress,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Thêm địa chỉ mới'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(AddressModel address, String? defaultAddressId) {
    final isDefault = defaultAddressId == address.id;
    final isSelected = widget.selectedAddressId == address.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.selectionMode && address.isVerified
              ? () => Navigator.pop(context, address.id)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: address.isVerified
                        ? AppColors.primaryContainer
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconFor(address),
                    color: address.isVerified
                        ? AppColors.primary
                        : AppColors.textHint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddressHeader(address, isSelected,
                          isDefault: isDefault),
                      const SizedBox(height: 6),
                      Text(
                        address.fullAddress,
                        style: TextStyle(
                          color: address.isVerified
                              ? AppColors.textSecondary
                              : AppColors.textHint,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!address.isVerified) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Cần chọn lại từ danh sách gợi ý trước khi đặt lịch.',
                          style:
                              TextStyle(color: AppColors.warning, fontSize: 12),
                        ),
                      ],
                      if (!widget.selectionMode &&
                          !isDefault &&
                          address.isVerified) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _setAsDefault(address),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_border,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Đặt làm mặc định',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.selectionMode)
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? AppColors.primary
                        : address.isVerified
                            ? AppColors.textHint
                            : AppColors.divider,
                    size: 22,
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                    onPressed: () => _deleteAddress(address),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressHeader(
    AddressModel address,
    bool isSelected, {
    required bool isDefault,
  }) {
    final title = Text(
      address.displayLabel,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        title,
        if (isDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Mặc định',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (isSelected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Đang chọn',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!address.isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Chưa xác minh',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Không tải được danh sách địa chỉ.',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(addressStoreProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _addNewAddress,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Thêm địa chỉ mới'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_off_outlined,
              color: AppColors.textSecondary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bạn chưa có địa chỉ nào. Thêm ngay để đặt lịch.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

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

class _AddressFormDialog extends ConsumerStatefulWidget {
  const _AddressFormDialog();

  @override
  ConsumerState<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<_AddressFormDialog> {
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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 12),
              VerifiedAddressField(
                onChanged: (value) => setState(() => _selectedPlace = value),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn cần chọn một dòng gợi ý để CareSitter xác minh vị trí.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                    _AddressFormData(
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

class _AddressFormData {
  final String title;
  final String placeId;
  final String sessionToken;

  const _AddressFormData({
    required this.title,
    required this.placeId,
    required this.sessionToken,
  });
}
