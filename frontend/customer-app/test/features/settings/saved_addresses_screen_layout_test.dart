import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/saved_addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saved addresses selection is responsive and returns address id',
      (tester) async {
    tester.view.physicalSize = const Size(260, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressStoreProvider.overrideWith(_FakeAddressStore.new),
        ],
        child: const MaterialApp(home: _SelectionHarness()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mở chọn địa chỉ'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn địa chỉ chăm sóc'), findsOneWidget);
    expect(find.text('Đang chọn'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Nhà riêng'));
    await tester.pumpAndSettle();

    expect(find.text('selected-address-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAddressStore extends AddressStore {
  @override
  Future<List<AddressModel>> build() async => const [
        AddressModel(
          id: 'selected-address-1',
          label: 'Văn phòng',
          fullAddress:
              '78 Điện Biên Phủ, Phường 15, Quận Bình Thạnh, TP. Hồ Chí Minh',
          isVerified: true,
        ),
        AddressModel(
          id: 'selected-address-2',
          label: 'Nhà riêng',
          fullAddress: '123 Lê Văn Sỹ, Phường 13, Quận 3, TP. Hồ Chí Minh',
          isVerified: true,
        ),
      ];
}

class _SelectionHarness extends StatefulWidget {
  const _SelectionHarness();

  @override
  State<_SelectionHarness> createState() => _SelectionHarnessState();
}

class _SelectionHarnessState extends State<_SelectionHarness> {
  String? _selectedAddressId = 'selected-address-1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                final selectedAddressId = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SavedAddressesScreen(
                      selectionMode: true,
                      selectedAddressId: _selectedAddressId,
                    ),
                  ),
                );
                if (selectedAddressId != null) {
                  setState(() => _selectedAddressId = selectedAddressId);
                }
              },
              child: const Text('Mở chọn địa chỉ'),
            ),
            if (_selectedAddressId != null) Text(_selectedAddressId!),
          ],
        ),
      ),
    );
  }
}
