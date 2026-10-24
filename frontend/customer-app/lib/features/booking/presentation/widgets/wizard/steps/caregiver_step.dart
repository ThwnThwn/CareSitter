import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_selectors.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../common/wizard_card.dart';

class CaregiverStep extends ConsumerWidget {
  const CaregiverStep({super.key, required this.args});
  final BookingWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(bookingWizardProvider(args)
        .select((s) => (s.systemMatched, s.caregiverId)));
    return ref.watch(wizardCandidatesProvider(args)).when(
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator())),
        error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(wizardCandidatesProvider(args)),
            child: const Text('Thử lại')),
        data: (items) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Chọn người chăm sóc',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text('${items.length} chăm sóc viên đang trực tuyến',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: AppSpacing.md),
              WizardCard(
                  selected: choice.$1,
                  highlightSelected: true,
                  onTap: () => ref
                      .read(bookingWizardProvider(args).notifier)
                      .selectCaregiver(null),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.compact),
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Để hệ thống gợi ý',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700)),
                          Text('Hệ thống sẽ chọn người phù hợp nhất cho bạn',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ])),
                    if (choice.$1)
                      const Icon(Icons.check_circle, color: AppColors.primary),
                  ])),
              if (items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                const Text('Hoặc tự chọn chăm sóc viên',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.control),
              ],
              for (final caregiver in items)
                _CaregiverCard(
                    caregiver: caregiver,
                    selected: choice.$2 == caregiver.id,
                    onTap: () => ref
                        .read(bookingWizardProvider(args).notifier)
                        .selectCaregiver(caregiver.id)),
              if (items.isEmpty)
                const Text(
                    'Chưa có chăm sóc viên trực tuyến. Bạn có thể để hệ thống tự ghép.'),
            ]));
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard(
      {required this.caregiver, required this.selected, required this.onTap});
  final CaregiverModel caregiver;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WizardCard(
      selected: selected,
      onTap: onTap,
      child: Row(children: [
        Stack(children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryLight,
              backgroundImage:
                  AssetImage(defaultAvatarAsset(seed: caregiver.initials))),
          if (caregiver.isOnline)
            Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)))),
        ]),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(caregiver.displayName,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          Row(children: [
            const Icon(Icons.star, size: 12, color: AppColors.warning),
            const SizedBox(width: AppSpacing.tiny),
            Text(
                '${caregiver.ratingAvg.toStringAsFixed(1)} • ${caregiver.yearsOfExperience ?? 3} năm',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
          if (caregiver.hourlyRateExpected != null)
            Text('${formatVnd(caregiver.hourlyRateExpected!)} / giờ',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
        ])),
        if (selected)
          const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
      ]));
}
