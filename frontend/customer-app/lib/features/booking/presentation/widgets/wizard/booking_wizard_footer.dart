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
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        safeBottom > AppSpacing.md ? safeBottom : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.98),
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppLayout.authFormMaxWidth),
          child: Row(children: [
            if (flow.step > 0) ...[
              _BackButton(
                enabled: enabled,
                onPressed:
                    ref.read(bookingWizardProvider(args).notifier).previous,
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
        ),
      ),
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
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
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
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          minimumSize: const Size(double.infinity, 52),
          animationDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
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
