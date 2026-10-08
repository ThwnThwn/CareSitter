import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let defines = Bundle.main.object(forInfoDictionaryKey: "CareSitterDartDefines") as? String {
      for encoded in defines.split(separator: ",") {
        guard let data = Data(base64Encoded: String(encoded)),
              let value = String(data: data, encoding: .utf8),
              value.hasPrefix("GOOGLE_MAPS_IOS_API_KEY=") else { continue }
        let key = String(value.dropFirst("GOOGLE_MAPS_IOS_API_KEY=".count))
        if !key.isEmpty { GMSServices.provideAPIKey(key) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
