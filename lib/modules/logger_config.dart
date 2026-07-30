// lib/modules/logger_config.dart
// Centralized logger configuration & strategy dispatcher for JA Sync

import 'build_info.dart';
import 'logger_release.dart';
import 'logger_debug.dart';

export 'logger_release.dart';
export 'logger_debug.dart';

/// Configures logger based on application runtime mode (Debug vs Release)
void setupLogger() {
  if (BuildInfo.isDebug) {
    setupDebugLogger();
  } else {
    setupReleaseLogger();
  }
}

/// Disposes log file sinks
void disposeLogger() {
  if (BuildInfo.isDebug) {
    disposeDebugLogger();
  } else {
    disposeReleaseLogger();
  }
}
