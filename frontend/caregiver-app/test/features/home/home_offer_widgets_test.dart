import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_details.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_actions.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

// These are layout/interaction tests. A bundled font supplies deterministic
// metrics without downloading Google Fonts during the test.
class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
        for (final variant in [
          'Regular',
          'Medium',
          'SemiBold',
          'Bold',
          'Italic'
        ])
          'test-fonts/BeVietnamPro-$variant.ttf',
      ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

const shift = ShiftModel(
    id: 'offer',
    beneficiaryName: 'Nguyễn Văn An',
    caregiverName: 'Caregiver',
    caregiverAvatar: 'CG',
    serviceName: 'Chăm sóc tại nhà',
    status: 'open',
    totalPrice: 300000,
    caregiverEarning: 240000,
    address: 'TP. Hồ Chí Minh');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    final font = await rootBundle.load('assets/fonts/InterVariable.ttf');
    GoogleFonts.config.allowRuntimeFetching = false;
    font_loader.assetManifest = _FontManifest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final path = const StringCodec().decodeMessage(message);
      if (path?.startsWith('test-fonts/') == true) return font;
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    font_loader.assetManifest = null;
    font_loader.clearCache();
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'offer details and actions fit width $width without conflating taps',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = 0, accepted = 0, declined = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.4)),
            child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    HomeOfferDetails(
                        isExpired: false,
                        countdownLabel: 'Còn 01:00',
                        pendingCount: 1,
                        booking: shift,
                        offerLocationLabel: (_) => 'TP. Hồ Chí Minh',
                        formatPrice: (_) => '240.000',
                        turnaroundWarning: null,
                        note: null,
                        callbackAction2: () {
                          opened++;
                        },
                        callbackAction3: () {}),
                    HomeOfferActions(
                        isExpired: false,
                        isProcessing: false,
                        booking: shift,
                        runOfferAction: (context, id,
                                {required action, required successMessage}) =>
                            action(),
                        callbackAction2: () async {
                          declined++;
                        },
                        callbackAction3: () async {
                          accepted++;
                        }),
                  ])),
            )),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Chưa có ghi chú'), findsOneWidget);
      await tester.ensureVisible(find.text('Nhận ca ngay'));
      await tester.tap(find.text('Nhận ca ngay'));
      await tester.tap(find.text('Từ chối'));
      await tester.pump();
      expect(accepted, 1);
      expect(declined, 1);
      expect(opened, 0);
      await tester.tap(find.text('Chăm sóc tại nhà'));
      await tester.pump();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('expired or processing offers disable both mutation actions',
      (tester) async {
    for (final flags in [(true, false), (false, true)]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: HomeOfferActions(
        isExpired: flags.$1,
        isProcessing: flags.$2,
        booking: shift,
        runOfferAction: (context, id,
                {required action, required successMessage}) =>
            action(),
        callbackAction2: () async {
          fail('Decline should be disabled');
        },
        callbackAction3: () async {
          fail('Accept should be disabled');
        },
      ))));
      await tester.pump();
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
