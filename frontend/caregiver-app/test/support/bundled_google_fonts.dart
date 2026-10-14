import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
        for (final variant in [
          'Regular',
          'Medium',
          'SemiBold',
          'Bold',
          'ExtraBold',
          'Italic'
        ])
          'test-fonts/BeVietnamPro-$variant.ttf',
      ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

Future<void> useBundledGoogleFonts() async {
  final font = await rootBundle.load('assets/fonts/InterVariable.ttf');
  GoogleFonts.config.allowRuntimeFetching = false;
  font_loader.assetManifest = _FontManifest();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    final path = const StringCodec().decodeMessage(message);
    return path?.startsWith('test-fonts/') == true ? font : null;
  });
}

void resetBundledGoogleFonts() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
  font_loader.assetManifest = null;
  font_loader.clearCache();
  GoogleFonts.config.allowRuntimeFetching = true;
}
