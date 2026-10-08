import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/saved_addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
  });
  late _AddressStore store;
  final deleteButton = find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'Xóa Nhà riêng',
  );

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_SignedOutAuth.new),
        addressStoreProvider.overrideWith(() => store = _AddressStore()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: const SavedAddressesScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'keeping an address cancels deletion at narrow width and large text',
      (tester) async {
    await open(tester, scale: 1.4);
    await tapDelete(tester);
    expect(find.text('Xóa địa chỉ?'), findsOneWidget);
    expect(store.calls, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đóng'));
    await tester.pumpAndSettle();
    expect(store.calls, 0);
    expect(find.text('Nhà riêng'), findsOneWidget);
  });

  testWidgets(
      'address deletion waits for success and prevents repeated requests',
      (tester) async {
    await open(tester);
    await tapDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa địa chỉ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.calls, 1);
    expect(find.text('Đã xóa địa chỉ'), findsNothing);
    expect(tester.widget<IconButton>(deleteButton).onPressed, isNull);

    store.result.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nhà riêng'), findsNothing);
    expect(find.text('Đã xóa địa chỉ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    AppToast.dismiss(tester.element(find.byType(SavedAddressesScreen)));
    await tester.pump();
  });

  testWidgets(
      'a rejected deletion keeps the address and shows the server error',
      (tester) async {
    await open(tester);
    await tapDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa địa chỉ'));
    await tester.pump();
    store.result.completeError(const AppApiException(
      message: 'Địa chỉ đang được sử dụng trong lịch hẹn.',
      statusCode: 409,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nhà riêng'), findsOneWidget);
    expect(
        find.text('Địa chỉ đang được sử dụng trong lịch hẹn.'), findsOneWidget);
    expect(find.text('Đã xóa địa chỉ'), findsNothing);
    expect(tester.widget<IconButton>(deleteButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    AppToast.dismiss(tester.element(find.byType(SavedAddressesScreen)));
    await tester.pump();
  });
}

class _SignedOutAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.initial();
}

class _AddressStore extends AddressStore {
  int calls = 0;
  final result = Completer<void>();

  @override
  Future<List<AddressModel>> build() async => const [
        AddressModel(
          id: 'address-1',
          label: 'Nhà riêng',
          fullAddress: '123 Nguyễn Huệ, Phường Bến Nghé, Thành phố Hồ Chí Minh',
          isVerified: true,
        ),
      ];

  @override
  Future<void> deleteAddress(String id) async {
    calls++;
    await result.future;
    state = AsyncData(state.requireValue.where((a) => a.id != id).toList());
  }
}
