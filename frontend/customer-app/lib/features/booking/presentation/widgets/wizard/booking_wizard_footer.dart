import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../controllers/booking_wizard_controller.dart';
import '../../controllers/booking_wizard_state.dart';
import '../../controllers/booking_wizard_selectors.dart';

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
    return Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.compact, AppSpacing.md, AppSpacing.wide),
        decoration: BoxDecoration(color: AppColors.cardBackground, boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ]),
        child: Row(children: [
          if (flow.step > 0) ...[
            IconButton(
                tooltip: 'Quay lại bước trước',
                onPressed: enabled
                    ? ref.read(bookingWizardProvider(args).notifier).previous
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.compact)))),
            const SizedBox(width: AppSpacing.compact)
          ],
          Expanded(
              child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: ready && enabled
                      ? (flow.step == 5
                          ? onSubmit
                          : ref.read(bookingWizardProvider(args).notifier).next)
                      : null,
                  child: Text(
                      flow.submitting
                          ? flow.submitLabel
                          : flow.step == 5
                              ? 'Xác nhận đặt lịch'
                              : 'Tiếp theo',
                      textAlign: TextAlign.center))),
        ]));
  }
}
