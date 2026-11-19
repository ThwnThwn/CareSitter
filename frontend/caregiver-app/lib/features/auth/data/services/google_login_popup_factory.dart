import '../../domain/google_login_popup.dart';
import 'google_login_popup_stub.dart'
    if (dart.library.js_interop) 'google_login_popup_web.dart' as platform;

GoogleLoginPopup? createGoogleLoginPopup(Uri startUri) =>
    platform.createPopup(startUri);
