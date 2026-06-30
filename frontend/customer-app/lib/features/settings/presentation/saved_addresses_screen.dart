import 'package:flutter/material.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final List<Map<String, String>> _addresses = [
    {
      'id': '1',
      'title': 'Nhà riêng',
      'address': '123 Lê Văn Sỹ, Phường 13, Quận 3, TP. Hồ Chí Minh',
      'isDefault': 'true',
      'icon': 'home'
    },
    {
      'id': '2',
      'title': 'Nhà bố mẹ',
      'address':
          '456 Nguyễn Trọng Tuyển, Phường 15, Quận Phú Nhuận, TP. Hồ Chí Minh',
      'isDefault': 'false',
      'icon': 'family'
    },
    {
      'id': '3',
      'title': 'Văn phòng',
      'address': '78 Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh',
      'isDefault': 'false',
      'icon': 'work'
    },
  ];

  void _addNewAddress() {
    final titleCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm địa chỉ mới',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Tên địa điểm (Ví dụ: Nhà riêng, Công ty)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && addrCtrl.text.isNotEmpty) {
                setState(() {
                  _addresses.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': titleCtrl.text,
                    'address': addrCtrl.text,
                    'isDefault': 'false',
                    'icon': 'location',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Đã thêm địa chỉ mới!')));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Địa chỉ đã lưu'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._addresses.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: a['isDefault'] == 'true'
                          ? AppColors.primary
                          : AppColors.border,
                      width: a['isDefault'] == 'true' ? 1.5 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        a['icon'] == 'home'
                            ? Icons.home_outlined
                            : (a['icon'] == 'work'
                                ? Icons.work_outline
                                : Icons.location_on_outlined),
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(a['title']!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary)),
                              if (a['isDefault'] == 'true') ...[
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
                          const SizedBox(height: 6),
                          Text(a['address']!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textHint, size: 20),
                      onPressed: () {
                        setState(() => _addresses
                            .removeWhere((item) => item['id'] == a['id']));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã xoá địa chỉ')));
                      },
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addNewAddress,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Thêm địa chỉ mới'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}
