import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_provider_model.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_checkout_sheet_selected_provider_inset.dart';

class PaymentProviderChoices extends StatelessWidget {
  const PaymentProviderChoices(
      {super.key,
      required this.providers,
      required this.selected,
      required this.busy,
      required this.onSelected});
  final AsyncValue<List<PaymentProviderModel>> providers;
  final String? selected;
  final bool busy;
  final ValueChanged<PaymentProviderModel> onSelected;
  @override
  Widget build(BuildContext context) => providers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Text('Không tải được cách thanh toán. Vui lòng thử lại.'),
        data: (items) => Column(children: [
          for (final provider in items)
            PaymentCheckoutSheetSelectedProviderInset(
                provider: provider,
                selected: selected,
                submitting: busy,
                callbackAction1: () => onSelected(provider)),
          if (!items.any((p) => p.enabled))
            const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                    'Thanh toán trực tuyến hiện chưa mở. Vui lòng liên hệ hỗ trợ.',
                    style: TextStyle(color: AppColors.textSecondary))),
        ]),
      );
}
