import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/self_recipient_controller.dart';
import 'self_recipient_step.dart';
import 'recipient_card.dart';

class RecipientStep extends ConsumerWidget {
  const RecipientStep({super.key, required this.args});
  final BookingWizardArgs args;
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull?.userId;
    final id = await context.push<String>(AppRoutes.beneficiaryNew);
    if (!context.mounted ||
        ref.read(authStateProvider).valueOrNull?.userId != user ||
        id == null) {
      return;
    }
    ref.invalidate(bookingRecipientsProvider);
    try {
      final items = await ref.read(bookingRecipientsProvider.future);
      if (!context.mounted ||
          ref.read(authStateProvider).valueOrNull?.userId != user) {
        return;
      }
      final profile = items.where((b) => b.id == id && !b.isSelf).firstOrNull;
      if (profile != null) {
        ref.read(bookingWizardProvider(args).notifier).selectRecipient(profile);
      }
    } catch (_) {/* Provider hiển thị lỗi tải và thử lại. */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(bookingWizardProvider(args)
        .select((s) => (s.forSelf, s.beneficiaryId)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bạn đặt dịch vụ cho ai?',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.compact),
      SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Tôi'),
                icon: Icon(Icons.person_outline)),
            ButtonSegment(
                value: false,
                label: Text('Người thân'),
                icon: Icon(Icons.people_outline)),
          ],
          selected: {
            choice.$1
          },
          onSelectionChanged: (v) =>
              ref.read(bookingWizardProvider(args).notifier).forSelf(v.single)),
      const SizedBox(height: AppSpacing.section),
      if (choice.$1)
        SelfRecipientStep(args: args)
      else
        _relativeRecipients(context, ref, choice.$2),
    ]);
  }

  Widget _relativeRecipients(
      BuildContext context, WidgetRef ref, String? selectedId) {
    return ref.watch(bookingRecipientsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(bookingRecipientsProvider),
            child: const Text('Thử lại')),
        data: (items) {
          final relatives = items.where((b) => !b.isSelf).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (relatives.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Chưa có hồ sơ người thân. Bạn có thể thêm ngay tại đây.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ...relatives.map(
                (beneficiary) => RecipientCard(
                  beneficiary: beneficiary,
                  isSelected: selectedId == beneficiary.id,
                  onTap: () => ref
                      .read(bookingWizardProvider(args).notifier)
                      .selectRecipient(beneficiary),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Thêm người thân mới'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => _add(context, ref),
                ),
              ),
            ],
          );
        });
  }
}
