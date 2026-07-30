// lib/modules/utils.dart
// Shared utility helper functions for JA Sync

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'app_config.dart';

final _logger = Logger('SyncUtils');

/// File information structure for sync comparison
class FileInfo {
  final String relativePath;
  final int size;
  final DateTime mtime;
  final bool isDirectory;
  final bool isInaccessible;

  FileInfo({
    required this.relativePath,
    required this.size,
    required this.mtime,
    required this.isDirectory,
    this.isInaccessible = false,
  });

  Map<String, dynamic> toJson() => {
        'path': relativePath,
        'size': size,
        'mtime': mtime.millisecondsSinceEpoch,
        'isDir': isDirectory,
        'isInaccessible': isInaccessible,
      };

  factory FileInfo.fromJson(Map<String, dynamic> json) => FileInfo(
        relativePath: json['path'],
        size: json['size'],
        mtime: DateTime.fromMillisecondsSinceEpoch(json['mtime']),
        isDirectory: json['isDir'] ?? false,
        isInaccessible: json['isInaccessible'] ?? false,
      );
}

/// Format timestamp for files: yyyy-MM-dd_HH-mm-ss
String formatTimestamp([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}-'
      '${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Format timestamp for UI display: yyyy-MM-dd HH:mm:ss
String formatTimestampDisplay([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Normalize path for current OS representation
String normalizePath(String path) {
  return p.normalize(path);
}

/// Format file size in human-readable units
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

bool isSystemIgnored(String path) {
  if (path.isEmpty) return false;

  // Normalize path separators to forward slashes
  final normalized = path.replaceAll(r'\', '/');
  final segments = normalized
      .split('/')
      .where((s) => s.isNotEmpty)
      .map((s) => s.toLowerCase())
      .toList();
  if (segments.isEmpty) return false;

  final ignoredDirectories = AppConfig.getSystemExcludes()
      .map((e) => e.toLowerCase())
      .toSet();

  // Check if any segment is an ignored directory
  for (final seg in segments) {
    if (ignoredDirectories.contains(seg)) {
      return true;
    }
  }

  // Check the last segment (file or directory name)
  final filename = segments.last;
  if (filename == 'thumbs.db' ||
      filename == 'desktop.ini' ||
      filename == '.ds_store' ||
      filename == 'ehthumbs.db') {
    return true;
  }

  if (filename.startsWith(r'~$') ||
      filename.startsWith(r'.~') ||
      filename.endsWith('.tmp') ||
      filename.endsWith('.crdownload') ||
      filename.endsWith('.part')) {
    return true;
  }

  return false;
}

/// Efficiently scans directory using non-recursive queue traversal to avoid entering ignored sub-trees
Future<Map<String, FileInfo>> scanDirectory(String rootPath) async {
  final Map<String, FileInfo> fileMap = {};
  final rootDir = Directory(rootPath);
  try {
    if (!await rootDir.exists()) return fileMap;
  } catch (_) {
    return fileMap;
  }

  final List<Directory> queue = [rootDir];
  int itemCount = 0;

  while (queue.isNotEmpty) {
    final currentDir = queue.removeLast();
    try {
      await for (final entity in currentDir.list(followLinks: false)) {
        itemCount++;
        if (itemCount % 50 == 0) {
          await Future.delayed(Duration.zero); // Yield control to event loop
        }

        final relPath = p.relative(entity.path, from: rootPath);
        final uniformKey = relPath.replaceAll(r'\', '/');

        if (isSystemIgnored(uniformKey)) continue;

        try {
          final stat = await entity.stat();
          if (stat.type == FileSystemEntityType.file) {
            fileMap[uniformKey] = FileInfo(
              relativePath: uniformKey,
              size: stat.size,
              mtime: stat.modified,
              isDirectory: false,
              isInaccessible: false,
            );
          } else if (stat.type == FileSystemEntityType.directory) {
            fileMap[uniformKey] = FileInfo(
              relativePath: uniformKey,
              size: 0,
              mtime: stat.modified,
              isDirectory: true,
              isInaccessible: false,
            );
            queue.add(Directory(entity.path)); // Enqueue ONLY non-ignored subdirectories
          }
        } catch (_) {
          final isDir = entity is Directory;
          fileMap[uniformKey] = FileInfo(
            relativePath: uniformKey,
            size: 0,
            mtime: DateTime.fromMillisecondsSinceEpoch(0),
            isDirectory: isDir,
            isInaccessible: true,
          );
          if (isDir) {
            queue.add(Directory(entity.path));
          }
        }
      }
    } catch (e) {
      _logger.warning('Skipped inaccessible sub-directory ${currentDir.path}: $e');
    }
  }
  return fileMap;
}

/// Configures the application to start with Windows by modifying HKCU run registry key.
Future<bool> setStartWithWindows(bool enable) async {
  if (!Platform.isWindows) return false;
  final exePath = Platform.resolvedExecutable;
  try {
    if (enable) {
      final result = await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'JA_Sync',
        '/t',
        'REG_SZ',
        '/d',
        '"$exePath"',
        '/f',
      ]);
      return result.exitCode == 0;
    } else {
      final result = await Process.run('reg', [
        'delete',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'JA_Sync',
        '/f',
      ]);
      return result.exitCode == 0;
    }
  } catch (_) {
    return false;
  }
}

/// Checks if start with Windows is enabled for the current executable in HKCU run registry.
Future<bool> isStartWithWindowsEnabled() async {
  if (!Platform.isWindows) return false;
  try {
    final result = await Process.run('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
      '/v',
      'JA_Sync',
    ]);
    if (result.exitCode == 0) {
      final exePath = Platform.resolvedExecutable;
      // Registry query output will contain the executable path
      return result.stdout.toString().contains(exePath);
    }
    return false;
  } catch (_) {
    return false;
  }
}
