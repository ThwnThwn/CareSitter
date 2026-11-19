import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/booking_promotion_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../booking_price_breakdown.dart';
import 'booking_total_card.dart';
import 'booking_voucher_sheet.dart';
import 'wizard_card.dart';

class BookingPromotionField extends ConsumerWidget {
  const BookingPromotionField({
    super.key,
    required this.args,
    required this.estimatedAmount,
  });

  final BookingWizardArgs args;
  final num? estimatedAmount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingWizardProvider(args));
    final promotion = ref.watch(bookingPromotionProvider(args));
    final quote = promotion.quoteFor(flow.promotionSlot);
    final canOpen = !flow.submitting &&
        !flow.uncertain &&
        !promotion.checking &&
        flow.promotionSlot != null;
    final status = quote != null
        ? '${quote.code} · Giảm ${formatVnd(quote.discountAmount)}'
        : promotion.hasCode
            ? '${promotion.code} · Cần kiểm tra lại'
            : 'Chọn hoặc nhập mã';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardCard(
          onTap: canOpen
              ? () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    constraints: const BoxConstraints(
                        maxWidth: AppLayout.authFormMaxWidth),
                    builder: (_) => BookingVoucherSheet(args: args),
                  )
              : null,
          child: Row(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã ưu đãi',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(status,
                        style: TextStyle(
                            color: quote != null
                                ? AppColors.primaryDark
                                : AppColors.textSecondary)),
                    if (promotion.error case final message?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(message,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                  ],
                ),
              ),
              if (canOpen)
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
        if (quote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.inset, 0, AppSpacing.inset, AppSpacing.compact),
            child: BookingPriceBreakdown(
              grossAmount: quote.grossAmount,
              discountAmount: quote.discountAmount,
            ),
          ),
        BookingTotalCard(
          label: quote == null ? 'Tạm tính' : 'Cần thanh toán',
          amount: quote?.customerPayableAmount ?? estimatedAmount,
        ),
      ],
    );
  }
}
