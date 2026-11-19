import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_quote_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/booking_promotion_controller.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import 'booking_voucher_list.dart';

class BookingVoucherSheet extends ConsumerStatefulWidget {
  const BookingVoucherSheet({super.key, required this.args});
  final BookingWizardArgs args;

  @override
  ConsumerState<BookingVoucherSheet> createState() =>
      _BookingVoucherSheetState();
}

class _BookingVoucherSheetState extends ConsumerState<BookingVoucherSheet> {
  late final TextEditingController _input;
  String? _error;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
        text: ref.read(bookingPromotionProvider(widget.args)).code);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _select(String code) {
    FocusScope.of(context).unfocus();
    _input.text = code;
    setState(() => _error = null);
  }

  Future<void> _apply(PromotionBookingSlot slot) async {
    final provider = bookingPromotionProvider(widget.args);
    final promotion = ref.read(provider);
    final code = _input.text.trim().toUpperCase();
    if (promotion.checking || code.isEmpty) return;
    if (promotion.quoteFor(slot)?.code == code) {
      Navigator.of(context).pop();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final error = await ref.read(provider.notifier).apply(
          slot,
          candidateCode: promotion.code == code ? null : code,
        );
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = bookingPromotionProvider(widget.args);
    final promotion = ref.watch(provider);
    final slot = ref.watch(bookingWizardProvider(widget.args)
        .select((flow) => flow.promotionSlot));
    ref.listen(
        authStateProvider.select((auth) => (
              auth.valueOrNull?.userId,
              auth.valueOrNull?.isAuthenticated,
              ref.read(authStateProvider.notifier).sessionGeneration,
            )), (_, __) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });

    final checking = promotion.checking;
    final selected = _input.text.trim().toUpperCase();
    final apply = slot == null || selected.isEmpty || checking
        ? null
        : () => _apply(slot);
    final controls = _VoucherActions(
      checking: checking,
      onApply: apply,
      onRemove: !checking && promotion.hasCode
          ? () {
              ref.read(provider.notifier).setCode('');
              Navigator.of(context).pop();
            }
          : null,
    );
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(provider.notifier).cancelPreview();
      },
      child: _VoucherLayout(
        input: TextField(
          controller: _input,
          enabled: !checking,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: BookingPromotionController.maxCodeLength,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => apply?.call(),
          decoration: InputDecoration(
            labelText: 'Nhập mã ưu đãi',
            counterText: '',
            prefixIcon: const Icon(Icons.tag),
            errorText: _error,
            errorMaxLines: 5,
          ),
        ),
        list: BookingVoucherList(
          serviceId: slot?.serviceTypeId,
          selectedCode: selected,
          onSelect: checking ? null : _select,
        ),
        controls: controls,
      ),
    );
  }
}

class _VoucherLayout extends StatelessWidget {
  const _VoucherLayout(
      {required this.input, required this.list, required this.controls});

  final Widget input, list, controls;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final maxHeight = constraints.maxHeight * 0.86;
            final compact = maxHeight < 300;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact) const _VoucherHeader(),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        if (compact) const _VoucherHeader(),
                        input,
                        if (compact) controls,
                        const SizedBox(height: AppSpacing.lg),
                        list,
                      ],
                    ),
                  ),
                  if (!compact) controls,
                ],
              ),
            );
          }),
        ),
      );
}

class _VoucherHeader extends StatelessWidget {
  const _VoucherHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
                child: Text('Chọn mã ưu đãi',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
              tooltip: 'Đóng ưu đãi',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}

class _VoucherActions extends StatelessWidget {
  const _VoucherActions(
      {required this.checking, required this.onApply, this.onRemove});
  final bool checking;
  final VoidCallback? onApply, onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            if (onRemove != null) ...[
              Flexible(
                  child: TextButton(
                      onPressed: onRemove, child: const Text('Bỏ mã'))),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: FilledButton(
                onPressed: onApply,
                child: Text(checking ? 'Đang kiểm tra…' : 'Áp dụng'),
              ),
            ),
          ],
        ),
      );
}
