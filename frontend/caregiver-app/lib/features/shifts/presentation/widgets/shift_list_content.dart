import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_card.dart';

class ShiftListContent extends ConsumerWidget {
  const ShiftListContent(
      {super.key,
      required this.filtered,
      required this.emptyIcon,
      required this.emptyTitle,
      required this.emptyMessage,
      required this.storageKey});
  final Iterable<ShiftModel> filtered;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String storageKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = filtered.toList(growable: false);
    if (shifts.isEmpty) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.builder(
      key: PageStorageKey(storageKey),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: shifts.length,
      itemBuilder: (context, index) {
        final shift = shifts[index];
        final isInvitation = shift.canAccept;
        return ShiftCard(
          shift: shift,
          onTap: () => context.push(
            shift.statusType == ShiftStatus.inProgress
                ? '/shifts/${shift.id}/active'
                : '/shifts/${shift.id}',
          ),
          onDecline: isInvitation
              ? () => ref.read(shiftsProvider.notifier).declineBooking(shift.id)
              : null,
          onViewOffer:
              isInvitation ? () => context.push('/shifts/${shift.id}') : null,
        );
      },
    );
  }
}
