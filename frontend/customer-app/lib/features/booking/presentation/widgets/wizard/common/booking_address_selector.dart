import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import '../../../controllers/booking_wizard_state.dart';
import 'booking_address_card.dart';

/// BookingAddressSelector theo Stitch design:
/// Card bo 18px với border brand khi selected, badge "Mặc định",
/// nút Quản lý địa chỉ với icon circle.
class BookingAddressSelector extends ConsumerWidget {
  const BookingAddressSelector({super.key, required this.args});
  final BookingWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(bookingWizardProvider(args).select((s) => s.addressId));
    final defaultAddressId =
        ref.watch(wizardRecipientProvider(args))?.defaultAddressId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AddressHeader(),
      const SizedBox(height: AppSpacing.compact),
      _AddressList(
        args: args,
        selectedId: selected,
        defaultAddressId: defaultAddressId,
      ),
      const SizedBox(height: AppSpacing.compact),
      _ManageAddressButton(
        onReturned: () => ref.invalidate(addressStoreProvider),
      ),
    ]);
  }
}

class _AddressHeader extends StatelessWidget {
  const _AddressHeader();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.compact,
      runSpacing: AppSpacing.xs,
      children: [
        Text('Địa chỉ chăm sóc',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                )),
        Text('Chọn 1 địa chỉ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textHint)),
      ],
    );
  }
}

class _AddressList extends ConsumerWidget {
  const _AddressList({
    required this.args,
    required this.selectedId,
    required this.defaultAddressId,
  });
  final BookingWizardArgs args;
  final String? selectedId;
  final String? defaultAddressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(addressStoreProvider).when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(addressStoreProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
          data: (items) {
            final verified = items.where((item) => item.isVerified).toList();
            if (verified.isEmpty) return const _EmptyAddressCard();
            return Column(children: [
              for (var index = 0; index < verified.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpacing.control),
                BookingAddressCard(
                  item: verified[index],
                  isSelected: selectedId == verified[index].id,
                  isDefault: defaultAddressId == verified[index].id,
                  onTap: () => ref
                      .read(bookingWizardProvider(args).notifier)
                      .selectAddress(verified[index].id),
                ),
              ],
            ]);
          },
        );
  }
}

class _EmptyAddressCard extends StatelessWidget {
  const _EmptyAddressCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Chọn địa chỉ đã xác minh để tiếp tục.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
}

class _ManageAddressButton extends StatelessWidget {
  const _ManageAddressButton({required this.onReturned});
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Quản lý địa chỉ chăm sóc',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () async {
          await context.push('/settings/addresses');
          if (context.mounted) onReturned();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Quản lý địa chỉ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
          ]),
        ),
      ),
    );
  }
}
