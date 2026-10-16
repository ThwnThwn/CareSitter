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
      Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.verified_user_outlined,
                color: AppColors.primary, size: 24)),
        const SizedBox(width: AppSpacing.compact),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Điều khoản & Đồng ý',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text('Vui lòng đọc kỹ trước khi xác nhận đặt lịch',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: AppSpacing.md),
      const BookingConsentContent(),
      const SizedBox(height: AppSpacing.section),
      Material(
          color:
              accepted ? AppColors.primaryContainer : AppColors.cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              side: BorderSide(
                  color: accepted ? AppColors.primary : AppColors.border,
                  width: accepted ? 2 : 1)),
          child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: accepted,
              onChanged: (v) => ref
                  .read(bookingWizardProvider(args).notifier)
                  .setConsent(v ?? false),
              title: const Text(
                  'Tôi đã đọc, hiểu và đồng ý với tất cả Điều khoản Dịch vụ và Chính sách Bảo mật của CareSitter. Tôi xác nhận rằng thông tin đã cung cấp là chính xác.',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.5)))),
      if (!accepted) const Text('Bạn cần đồng ý với điều khoản để tiếp tục'),
    ]);
  }
}
