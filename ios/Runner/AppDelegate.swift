import Flutter
import UIKit
// Google Maps SDK for iOS - required by google_maps_flutter. Without
// GMSServices.provideAPIKey the map renders for a few seconds and then shows
// a "Google Maps" error overlay. Keep this key identical to the ones in
// android/.../AndroidManifest.xml and web/index.html (see MAPS_SETUP.md).
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDa042Rj9pP-zgl4YoJumLXuOLUfcNxuBc")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
