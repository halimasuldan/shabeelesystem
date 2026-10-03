// GENERATED CODE - MANUAL TEMPLATE
// Replace this file with output from: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use in your application.
/// Run `flutterfire configure` to generate the proper options
/// for your Firebase project.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Replace these with your actual Firebase configuration

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQyIVc99Q70D2Jln-t8JObGxATBDkiVkg',
    appId: '1:98014689684:android:feb5f5e51d07fa8faab781',
    messagingSenderId: '98014689684',
    projectId: 'shabelleapp-e8ffd',
    storageBucket: 'shabelleapp-e8ffd.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  /// Placeholder web options - replace via flutterfire configure or
  /// Firebase Console > Project settings > Your apps > SDK setup.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDa042Rj9pP-zgl4YoJumLXuOLUfcNxuBc',
    appId: '1:98014689684:web:2f6729a29ab69588aab781',
    messagingSenderId: '98014689684',
    projectId: 'shabelleapp-e8ffd',
    authDomain: 'shabelleapp-e8ffd.firebaseapp.com',
    storageBucket: 'shabelleapp-e8ffd.firebasestorage.app',
    measurementId: 'G-36HYYF5MVG',
  );
}
