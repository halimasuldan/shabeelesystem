import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Installs the Crashlytics error hook on platforms that support it
/// (Android / iOS / macOS desktop VMs). Selected via conditional import.
void installCrashlyticsHook() {
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
}
