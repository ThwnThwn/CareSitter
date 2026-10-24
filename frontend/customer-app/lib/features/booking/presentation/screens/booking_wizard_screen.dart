import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../controllers/booking_wizard_controller.dart';
import '../controllers/booking_wizard_state.dart';
import '../controllers/booking_submit_result.dart';
import '../widgets/wizard/booking_wizard_body.dart';
import '../widgets/wizard/booking_wizard_footer.dart';
import '../widgets/wizard/booking_wizard_header.dart';
import '../widgets/wizard/booking_step_indicator.dart';

class BookingWizardScreen extends ConsumerWidget {
  const BookingWizardScreen(
      {super.key,
      this.initialServiceId,
      this.initialBeneficiaryId,
      this.initialCaregiverId});
  final String? initialServiceId, initialBeneficiaryId, initialCaregiverId;
  BookingWizardArgs get args =>
      (
        serviceId: initialServiceId,
        beneficiaryId: initialBeneficiaryId,
        caregiverId: initialCaregiverId,
      );
  Future<void> _submit(BuildContext context, WidgetRef ref,
      {bool reconcile = false}) async {
    final controller = ref.read(bookingWizardProvider(args).notifier);
    final result =
        await (reconcile ? controller.reconcile() : controller.submit());
    if (!context.mounted) return;
    switch (result) {
      case BookingSubmitted(:final id, :final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message), backgroundColor: AppColors.success));
        context.pushReplacement(AppRoutes.bookingDetail(id));
      case BookingSubmitMessage(:final message, :final caregiverConflict):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            action: caregiverConflict
                ? SnackBarAction(
                    label: 'Chọn lại',
                    textColor: Colors.white,
                    onPressed: () => ref
                        .read(bookingWizardProvider(args).notifier)
                        .chooseCaregiverAgain())
                : null));
      case BookingSubmitIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingWizardProvider(args));
    return DiscardChangesGuard(
        hasChanges: () =>
            ref.read(bookingWizardProvider(args).notifier).hasChanges,
        fallbackRoute: AppRoutes.home,
        builder: (context, requestExit) => Scaffold(
            backgroundColor: AppColors.background,
            appBar: BookingWizardHeader(step: flow.step, onClose: requestExit),
            body: Column(children: [
              BookingStepIndicator(step: flow.step),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: AppLayout.authFormMaxWidth),
                              child: AbsorbPointer(
                                  absorbing: flow.submitting || flow.uncertain,
                                  child: FadeSlideStaggered(
                                      key: ValueKey(flow.step),
                                      index: 0,
                                      child: BookingWizardBody(
                                          args: args, step: flow.step))))))),
              if (flow.uncertain)
                Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Chưa xác định được lịch đã tạo hay chưa. Kiểm tra lịch đã gửi trước khi đặt tiếp.'),
                      TextButton(
                          onPressed: flow.submitting
                              ? null
                              : () => _submit(context, ref, reconcile: true),
                          child: const Text('Kiểm tra lịch đã gửi')),
                      TextButton(
                          onPressed: () => context.go(AppRoutes.bookings),
                          child: const Text('Xem danh sách lịch')),
                    ])),
              BookingWizardFooter(
                  args: args, onSubmit: () => _submit(context, ref)),
            ])));
  }
}
