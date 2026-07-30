// lib/modules/logger_debug.dart
// Debug Mode Logging Strategy: Highly detailed verbose logging (ALL level), auto-cleanup after 7 days

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

IOSink? _debugLogSink;

void setupDebugLogger() {
  Logger.root.level = Level.ALL;

  final logDir = Directory(p.join(Directory.current.path, 'logs'));
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final now = DateTime.now();
  final logFileName =
      'debug_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.log';
  final logFile = File(p.join(logDir.path, logFileName));
  _debugLogSink = logFile.openWrite(mode: FileMode.append);

  _debugLogSink?.writeln(
      '================ DEBUG LOG SESSION STARTED: ${now.toIso8601String()} ================');

  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer();
    buffer.write('[${record.time.toIso8601String()}] [DEBUG] ${record.level.name}: ${record.loggerName} - ${record.message}');
    if (record.error != null) {
      buffer.write('\n  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      buffer.write('\n  STACKTRACE: ${record.stackTrace}');
    }

    final fullLogText = buffer.toString();
    
    // Console & Log file output
    // ignore: avoid_print
    print(fullLogText);
    _debugLogSink?.writeln(fullLogText);
  });

  // Auto-delete debug logs older than 7 days
  rotateDebugLogs(logDir);
}

void rotateDebugLogs(Directory logDir) {
  try {
    final limitDate = DateTime.now().subtract(const Duration(days: 7));
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

void disposeDebugLogger() {
  _debugLogSink?.writeln('================ DEBUG LOG SESSION ENDED ================');
  _debugLogSink?.close();
}
