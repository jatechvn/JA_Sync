// lib/modules/logger_release.dart
// Release Mode Logging Strategy: Basic logging (INFO+), auto-cleanup after 30 days

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

IOSink? _releaseLogSink;

void setupReleaseLogger() {
  Logger.root.level = Level.INFO;

  final logDir = Directory(p.join(Directory.current.path, 'logs'));
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final now = DateTime.now();
  final logFileName =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.log';
  final logFile = File(p.join(logDir.path, logFileName));
  _releaseLogSink = logFile.openWrite(mode: FileMode.append);

  Logger.root.onRecord.listen((record) {
    if (record.level < Level.INFO) return; // Ignore fine debug logs in Release mode

    final message =
        '[${record.time}] ${record.level.name}: ${record.loggerName} - ${record.message}';
    
    // Console & Log file output
    // ignore: avoid_print
    print(message);
    _releaseLogSink?.writeln(message);
  });

  // Auto-delete logs older than 30 days (1 month)
  rotateReleaseLogs(logDir);
}

void rotateReleaseLogs(Directory logDir) {
  try {
    final limitDate = DateTime.now().subtract(const Duration(days: 30));
    final entities = logDir.listSync();
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.log')) {
        final stat = entity.statSync();
        if (stat.modified.isBefore(limitDate)) {
          entity.deleteSync();
        }
      }
    }
  } catch (_) {}
}

void disposeReleaseLogger() {
  _releaseLogSink?.close();
}
