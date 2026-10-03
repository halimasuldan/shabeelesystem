import 'package:flutter/foundation.dart';

/// No-op Crashlytics hook for platforms without Crashlytics support
/// (e.g. web). Keeps the same signature as [crashlytics_impl.dart].
void installCrashlyticsHook() {
  debugPrint('Crashlytics is not supported on this platform.');
}
