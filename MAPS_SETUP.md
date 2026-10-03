# Google Maps Setup

The driver portal shows Google Maps on three screens (Route Map, Live GPS
Tracking, and the admin maps). The map renders for a few seconds and then
shows an error whenever the **Maps API key is missing for that platform** or
the underlying API is not enabled for the key. This file is the single source
of truth for where the key goes and what must be enabled in Google Cloud.

## Where the key lives (keep all three in sync)

| Platform | File | Mechanism |
|----------|------|-----------|
| Web | `web/index.html` | `https://maps.googleapis.com/maps/api/js?key=...` script tag |
| Android | `android/app/src/main/AndroidManifest.xml` | `<meta-data android:name="com.google.android.geo.API_KEY" ...>` inside `<application>` |
| iOS | `ios/Runner/AppDelegate.swift` | `GMSServices.provideAPIKey("...")` |

The key currently used: `AIzaSyDa042Rj9pP-zgl4YoJumLXuOLUfcNxuBc`

## Google Cloud requirements (per key)

1. **Enable the APIs** (Google Cloud Console → APIs & Services → Library):
   * Maps SDK for Android
   * Maps SDK for iOS
   * Maps JavaScript API
   * (recommended) Directions API, Geocoding API if route/directions are added later
2. **Billing**: the project holding the key must have a billing account
   attached. Without billing the SDK returns `ApiNotEnabledMapError` /
   "This page can't load Google Maps correctly" a few seconds after the map
   appears.
3. **Key restrictions** (recommended):
   * Application restrictions → Android apps → package name
     `com.example.shabelle_system` + SHA-1 of your signing key
     (`./gradlew signingReport` or `keytool -list -v -keystore ...`)
   * Application restrictions → iOS apps → bundle id (from `ios/Runner.xcodeproj`)
   * Application restrictions → HTTP referrers → your web origin

## Verifying

* **Web**: browser console must not show `Google Maps JavaScript API error:
  RefererNotAllowedMapError` or `ApiNotEnabledMapError`.
* **Android**: run `flutter run --release` on a device; the Route Map should
  keep tiles after ~10 s with no "This page can't load Google Maps correctly"
  overlay. A *debug* build with a release-key-restricted API key will fail —
  add the debug SHA-1 or lift the restriction while developing.
* **iOS**: `cd ios && pod install`, run from Xcode; missing
  `GMSServices.provideAPIKey` shows the same error overlay on
  `GMSMapView`.

## Troubleshooting `ApiNotActivatedMapError`

If the browser console reports `Google Maps JavaScript API error:
ApiNotActivatedMapError`, the page and key are loading, but **Maps JavaScript
API is not enabled for the Google Cloud project that owns the key**. In Google
Cloud Console, select that project, open **APIs & Services → Library**, enable
**Maps JavaScript API**, then confirm billing is active and reload the web app.
The API key also needs to allow the app's web origin under its HTTP referrer
restrictions. Enabling Maps SDK for Android/iOS alone does not enable the web
JavaScript API.

This error cannot be fixed by changing Flutter widgets or rebuilding the app;
the API must be enabled on the key's Google Cloud project.

## Rotating the key

Update **all three** files above in the same commit, then rebuild
(`flutter clean && flutter run`). Rotating only one platform leaves the
others erroring after a few seconds of working tiles — which is exactly the
symptom this setup exists to fix.