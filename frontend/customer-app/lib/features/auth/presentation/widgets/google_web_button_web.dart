import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart';

Widget buildGoogleWebButton({required double width}) {
  return SizedBox(
    width: width,
    height: 48,
    child: renderButton(
      configuration: GSIButtonConfiguration(
        type: GSIButtonType.standard,
        theme: GSIButtonTheme.outline,
        size: GSIButtonSize.large,
        shape: GSIButtonShape.rectangular,
        text: GSIButtonText.signin,
        logoAlignment: GSIButtonLogoAlignment.left,
        minimumWidth: width.clamp(120, 400).toDouble(),
        locale: 'vi',
      ),
    ),
  );
}
