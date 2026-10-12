import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../common/booking_consent_content.dart';

class ConsentStep extends ConsumerWidget {
  const ConsentStep({super.key, required this.args});
  final BookingWizardArgs args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted =
        ref.watch(bookingWizardProvider(args).select((s) => s.consent));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Điều khoản & Đồng ý',
          style: Theme.of(context).textTheme.titleMedium),
      const Text('Vui lòng đọc kỹ trước khi xác nhận đặt lịch'),
      const SizedBox(height: AppSpacing.md),
      const BookingConsentContent(),
      const SizedBox(height: AppSpacing.section),
      CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: accepted,
          onChanged: (v) => ref
              .read(bookingWizardProvider(args).notifier)
              .setConsent(v ?? false),
          title: const Text(
              'Tôi đã đọc, hiểu và đồng ý với tất cả Điều khoản Dịch vụ và Chính sách Bảo mật của CareSitter. Tôi xác nhận rằng thông tin đã cung cấp là chính xác.')),
      if (!accepted) const Text('Bạn cần đồng ý với điều khoản để tiếp tục'),
    ]);
  }
}
