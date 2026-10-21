import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../controllers/booking_wizard_controller.dart';
import '../../controllers/booking_wizard_state.dart';
import '../../controllers/booking_wizard_selectors.dart';

/// BookingWizardFooter theo Stitch design:
/// Back button bo 2xl bg surfaceVariant, Next button brand-700 + arrow icon + shadow glow.
class BookingWizardFooter extends ConsumerWidget {
  const BookingWizardFooter(
      {super.key, required this.args, required this.onSubmit});
  final BookingWizardArgs args;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingWizardProvider(args));
    final ready = ref.watch(wizardCanContinueProvider(args));
    final enabled = !flow.submitting && !flow.uncertain;
    final isLastStep = flow.step == 5;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.compact,
        AppSpacing.md,
        AppSpacing.compact + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(children: [
        if (flow.step > 0) ...[
          _BackButton(
            enabled: enabled,
            onPressed: ref.read(bookingWizardProvider(args).notifier).previous,
          ),
          const SizedBox(width: AppSpacing.compact),
        ],
        Expanded(
          child: _ContinueButton(
            enabled: enabled && ready,
            submitting: flow.submitting,
            submitLabel: flow.submitLabel,
            isLastStep: isLastStep,
            onPressed: isLastStep
                ? onSubmit
                : ref.read(bookingWizardProvider(args).notifier).next,
          ),
        ),
      ]),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: enabled ? onPressed : null,
        child: Tooltip(
          message: 'Quay lại bước trước',
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              Icons.chevron_left_rounded,
              color: enabled ? AppColors.textPrimary : AppColors.textHint,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.submitting,
    required this.submitLabel,
    required this.isLastStep,
    required this.onPressed,
  });
  final bool enabled;
  final bool submitting;
  final String submitLabel;
  final bool isLastStep;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.primary : AppColors.border,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textHint,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        onPressed: enabled ? onPressed : null,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(
              submitting
                  ? submitLabel
                  : isLastStep
                      ? 'Xác nhận đặt lịch'
                      : 'Tiếp theo',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          if (!submitting && !isLastStep) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ]),
      ),
    );
  }
}
