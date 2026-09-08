import 'package:flutter/material.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final List<Map<String, String>> _methods = [
    {
      'id': '1',
      'type': 'visa',
      'name': 'Thẻ Quốc tế Visa / Mastercard',
      'details': '**** **** **** 4242',
      'isDefault': 'true'
    },
    {
      'id': '2',
      'type': 'momo',
      'name': 'Ví điện tử MoMo',
      'details': '0912 *** 678',
      'isDefault': 'false'
    },
    {
      'id': '3',
      'type': 'zalopay',
      'name': 'Ví ZaloPay',
      'details': 'Liên kết thành công',
      'isDefault': 'false'
    },
  ];

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Thêm phương thức thanh toán',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _buildAddOption(Icons.credit_card, 'Thẻ Tín dụng / Ghi nợ',
                'Visa, Mastercard, JCB'),
            _buildAddOption(Icons.account_balance_wallet_outlined,
                'Ví điện tử MoMo / ZaloPay / VNPay', 'Thanh toán tức thì'),
            _buildAddOption(Icons.account_balance_outlined,
                'Tài khoản ngân hàng (ATM)', 'Chuyển khoản trực tiếp'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('⚡ Chức năng liên kết cổng thanh toán đang được xử lý')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phương thức thanh toán'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._methods.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: m['isDefault'] == 'true'
                          ? AppColors.primary
                          : AppColors.border,
                      width: m['isDefault'] == 'true' ? 1.5 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        m['type'] == 'visa'
                            ? Icons.credit_card
                            : Icons.account_balance_wallet,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m['name']!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textPrimary)),
                              if (m['isDefault'] == 'true') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Mặc định',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(m['details']!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textHint, size: 20),
                      onPressed: () {
                        setState(() => _methods
                            .removeWhere((item) => item['id'] == m['id']));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Đã xoá phương thức thanh toán')));
                      },
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addPaymentMethod,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Thêm phương thức mới'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
