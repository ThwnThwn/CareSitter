import 'package:caresitter_customer/features/home/presentation/widgets/home_promotion_details_dialog.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_promotions_section.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';
import 'package:caresitter_customer/features/promotions/presentation/controllers/active_promotions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact offers can retry loading, copy codes, and show details',
      (tester) async {
    String? copiedCode;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedCode = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    var loads = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activePromotionsProvider.overrideWith((ref) async {
          if (++loads == 1) throw StateError('Network unavailable');
          return [
            PromotionModel(
              id: 'campaign',
              code: 'CARE20',
              title: 'Ưu đãi chăm sóc',
              summary: 'Giảm 20% cho ca đủ điều kiện',
              badgeText: 'Giảm 20%',
              endsAt: DateTime(2027, 1, 1),
              minOrderAmount: 300000,
              maxDiscountAmount: 100000,
              terms: ['Không quy đổi thành tiền mặt'],
            ),
          ];
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: HomePromotionsSection())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được ưu đãi.'), findsOneWidget);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('CARE20'), findsOneWidget);
    expect(find.text('Ưu đãi chăm sóc'), findsNothing);
    expect(find.byTooltip('Xem chi tiết ưu đãi'), findsNothing);
    final card = find.byKey(const ValueKey('campaign'));
    expect(tester.getSize(card), const Size(156, 168));
    await tester.tap(find.byTooltip('Sao chép mã CARE20'));
    await tester.pump();
    expect(copiedCode, 'CARE20');

    await tester.tap(find.descendant(of: card, matching: find.byType(Image)));
    await tester.pumpAndSettle();
    final dialog = find.byType(HomePromotionDetailsDialog);
    expect(dialog, findsOneWidget);
    expect(find.text('Ưu đãi chăm sóc'), findsOneWidget);
    expect(find.text('Giảm 20% cho ca đủ điều kiện'), findsOneWidget);
    expect(find.text('Đến 1/1/2027'), findsOneWidget);
    expect(find.text('Đơn tối thiểu 300.000đ'), findsOneWidget);
    expect(find.text('Giảm tối đa 100.000đ'), findsOneWidget);
    expect(find.text('Không quy đổi thành tiền mặt'), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.byType(Image)),
        findsOneWidget);

    copiedCode = null;
    await tester.tap(find.text('Sao chép mã'));
    await tester.pumpAndSettle();
    expect(copiedCode, 'CARE20');
    expect(find.text('Đã sao chép mã'), findsOneWidget);
    await tester
        .tap(find.descendant(of: dialog, matching: find.byTooltip('Đóng')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('illustrated offers align and scroll with large text on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        activePromotionsProvider.overrideWith((ref) async => [
              PromotionModel.fromJson({
                'id': 'welcome',
                'code': 'CHAOMUNG20',
                'title': 'Ưu đãi khách hàng mới',
                'summary': 'Giảm 20% cho đơn chăm sóc đầu tiên',
                'badgeText': 'Giảm 20%',
                'endsAt': '2027-12-31T23:59:59+07:00',
                'firstPaidBookingOnly': true,
              }),
              PromotionModel(
                id: 'calm',
                code: 'CARESITTER50',
                title: 'Chăm sóc an tâm',
                summary: 'Giảm 50.000đ cho đơn từ 300.000đ',
                badgeText: 'Giảm 50k',
                endsAt: DateTime(2027, 12, 31),
              ),
            ]),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(body: HomePromotionsSection()),
      ),
    ));
    await tester.pumpAndSettle();

    final welcome = find.byKey(const ValueKey('welcome'));
    final calm = find.byKey(const ValueKey('calm'));
    expect(tester.getSize(welcome), tester.getSize(calm));
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .map((widget) => widget.image),
      [
        const AssetImage('assets/images/promotion-welcome.webp'),
        const AssetImage('assets/images/promotion-calm.webp'),
      ],
    );

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('CARESITTER50').hitTestable(), findsOneWidget);

    await tester.tap(find.descendant(of: calm, matching: find.byType(Image)));
    await tester.pumpAndSettle();
    expect(find.text('Sao chép mã').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Đóng').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
