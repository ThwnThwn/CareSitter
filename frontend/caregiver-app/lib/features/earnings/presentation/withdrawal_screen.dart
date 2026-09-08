import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/mock/mock_data.dart';
import 'providers/earnings_provider.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  MockBankAccount? _selectedBank;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (MockData.bankAccounts.isNotEmpty) {
      _selectedBank = MockData.bankAccounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submitWithdrawal(double balance) {
    if (!_formKey.currentState!.validate() || _selectedBank == null) return;

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;

    if (amount < 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số tiền rút tối thiểu là 100,000 đ'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số dư khả dụng không đủ'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(seconds: 1500 ~/ 1000), () {
      if (mounted) {
        final success = ref.read(earningsProvider.notifier).withdraw(
              amount,
              _selectedBank!.bankName,
              _selectedBank!.accountNumber,
            );

        setState(() => _isLoading = false);

        if (success) {
          _showSuccessDialog(amount);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rút tiền thất bại, vui lòng thử lại'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 72,
            ),
            const SizedBox(height: 20),
            const Text(
              'Rút tiền thành công!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã gửi ${formatCurrency(amount)} đ đến tài khoản ${_selectedBank!.bankName} của bạn.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Quay lại ví',
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to earnings screen
                },
              ),
            ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Balance Display Card ──
              _buildBalanceCard(earnings.balance),
              const SizedBox(height: 24),

              // ── Amount Input ──
              const Text(
                'Nhập số tiền cần rút',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Vui lòng nhập số tiền';
                  if (double.tryParse(val) == null) return 'Số tiền không hợp lệ';
                  return null;
                },
                decoration: InputDecoration(
                  prefixText: 'đ ',
                  prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  hintText: '0',
                  suffixIcon: TextButton(
                    onPressed: () {
                      _amountController.text = earnings.balance.toInt().toString();
                    },
                    child: const Text('Rút hết', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // ── Bank Account Selector ──
              const Text(
                'Chọn tài khoản nhận tiền',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: MockData.bankAccounts.length,
                itemBuilder: (context, index) {
                  final bank = MockData.bankAccounts[index];
                  final isSelected = _selectedBank?.id == bank.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedBank = bank),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? AppShadows.card : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                bank.bankLogo,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bank.bankName,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${bank.accountHolder} • ${bank.accountNumber}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? AppColors.primary : AppColors.textHint,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // ── Submit Button ──
              AppButton(
                label: 'Xác nhận rút tiền',
                onPressed: _isLoading ? null : () => _submitWithdrawal(earnings.balance),
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư khả dụng',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCurrency(balance)} đ',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}
