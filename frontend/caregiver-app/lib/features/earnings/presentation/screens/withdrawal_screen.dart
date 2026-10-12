import 'package:caregiver_app/features/earnings/presentation/widgets/withdrawal_use_balance_action.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/earnings/presentation/controllers/earnings_controller.dart';
import 'package:caregiver_app/features/earnings/presentation/widgets/withdrawal_balance_card.dart';
import 'package:caregiver_app/features/earnings/presentation/widgets/withdrawal_bank_form.dart';
import 'package:caregiver_app/features/earnings/presentation/widgets/withdrawal_success_dialog.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal(double balance) async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;

    setState(() => _isLoading = true);

    final result = await ref.read(earningsProvider.notifier).withdraw(
          amount,
          _bankNameController.text.trim(),
          _accountNumberController.text.trim(),
          accountHolderName: _accountHolderController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == WithdrawalResult.ignored) return;
    if (result == WithdrawalResult.submitted) {
      showWithdrawalSuccessDialog(
        context,
        amount: amount,
        bankName: _bankNameController.text.trim(),
        onDismiss: () => Navigator.pop(context),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            WithdrawalResult.belowMinimum =>
              'Số tiền rút tối thiểu là 100,000 đ',
            WithdrawalResult.insufficientBalance => 'Số dư khả dụng không đủ',
            WithdrawalResult.unknown =>
              'Chưa xác định được kết quả rút tiền. Giữ nguyên thông tin và thử lại để kiểm tra.',
            WithdrawalResult.changedPayload =>
              'Đang có yêu cầu rút tiền chưa rõ kết quả. Giữ nguyên thông tin của yêu cầu đó để thử lại.',
            _ =>
              'Yêu cầu rút tiền chưa được chấp nhận. Vui lòng kiểm tra lại thông tin.',
          }),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rút tiền về tài khoản'),
        leading: const AppBackButton(fallbackRoute: '/earnings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Balance Display Card ──
              WithdrawalBalanceCard(balance: earnings.balance),
              const SizedBox(height: AppSpacing.lg),

              // ── Amount Input ──
              const Text(
                'Nhập số tiền cần rút',
                style: TextStyle(
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.compact),
              WithdrawalUseBalanceAction(
                  amountController: _amountController,
                  callbackAction1: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Vui lòng nhập số tiền';
                    }
                    if (double.tryParse(val) == null) {
                      return 'Số tiền không hợp lệ';
                    }
                    return null;
                  },
                  callbackAction2: () {
                    _amountController.text =
                        earnings.balance.toInt().toString();
                  }),
              const SizedBox(height: AppSpacing.lg),

              // ── Bank Account Inputs ──
              WithdrawalBankForm(
                bankNameController: _bankNameController,
                accountHolderController: _accountHolderController,
                accountNumberController: _accountNumberController,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Submit Button ──
              AppButton(
                label: 'Xác nhận rút tiền',
                onPressed: _isLoading
                    ? null
                    : () => _submitWithdrawal(earnings.balance),
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
