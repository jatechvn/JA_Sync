// lib/services/settings_service.dart
// Settings management and persistence for INI/JSON configurations

import 'dart:io';
import 'package:path/path.dart' as p;
import '../modules/app_config.dart';

class SettingsService {
  static String? _iniPath;

  static void initialize() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    _iniPath = p.join(exeDir, 'config.ini');
  }

  /// Load stored settings dictionary with sensible defaults
  static Map<String, dynamic> loadSettings() {
    final settings = <String, dynamic>{
      'license_author': 'John Alaa',
      'max_depth': 3,
      'auto_create_repo': true,
      'repo_public': false,
      'bg_blur': 10.0,
      'bg_opacity': 0.6,
      'dialog_blur': 2.0,
      'dialog_opacity': 0.8,
      'speed_limit': int.tryParse(AppConfig.get('speed_limit', defaultValue: '0')) ?? 0,
      'close_action': AppConfig.get('close_action', defaultValue: 'ask'),
      'start_with_windows': AppConfig.getBool('start_with_windows', defaultValue: false),
      'start_minimized': AppConfig.getBool('start_minimized', defaultValue: false),
      'system_excludes': AppConfig.getSystemExcludes(),
    };

    if (_iniPath != null) {
      final file = File(_iniPath!);
      if (file.existsSync()) {
        try {
          final lines = file.readAsLinesSync();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('#') || trimmed.startsWith(';') || !trimmed.contains('=')) continue;
            final parts = trimmed.split('=');
            final key = parts[0].trim().toLowerCase();
            final value = parts.sublist(1).join('=').trim();
            if (key == 'bg_blur') {
              settings['bg_blur'] = double.tryParse(value) ?? 10.0;
            } else if (key == 'bg_opacity') {
              settings['bg_opacity'] = double.tryParse(value) ?? 0.6;
            } else if (key == 'dialog_blur') {
              settings['dialog_blur'] = double.tryParse(value) ?? 2.0;
            } else if (key == 'dialog_opacity') {
              settings['dialog_opacity'] = double.tryParse(value) ?? 0.8;
            } else if (key == 'license_author') {
              settings['license_author'] = value;
            } else if (key == 'max_depth') {
              settings['max_depth'] = int.tryParse(value) ?? 3;
            } else if (key == 'auto_create_repo') {
              settings['auto_create_repo'] = value.toLowerCase() == 'true';
            } else if (key == 'repo_public') {
              settings['repo_public'] = value.toLowerCase() == 'true';
            } else if (key == 'system_excludes') {
              final list = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (list.isNotEmpty) {
                settings['system_excludes'] = list;
                AppConfig.setSystemExcludes(list);
              }
            }
          }
        } catch (_) {}
      }
    }
    return settings;
  }

  /// Save settings to config.ini and sync to AppConfig
  static Future<void> saveSettings(Map<String, dynamic> newSettings) async {
    if (_iniPath == null) initialize();

    final systemExcludes = newSettings['system_excludes'] is List
        ? List<String>.from(newSettings['system_excludes'])
        : AppConfig.getSystemExcludes();

    final buffer = StringBuffer();
    buffer.writeln('[General]');
    buffer.writeln('license_author=${newSettings['license_author'] ?? 'John Alaa'}');
    buffer.writeln('max_depth=${newSettings['max_depth'] ?? 3}');
    buffer.writeln('auto_create_repo=${newSettings['auto_create_repo'] ?? true}');
    buffer.writeln('repo_public=${newSettings['repo_public'] ?? false}');
    buffer.writeln();
    buffer.writeln('[Glassmorphism]');
    buffer.writeln('bg_blur=${newSettings['bg_blur'] ?? 10.0}');
    buffer.writeln('bg_opacity=${newSettings['bg_opacity'] ?? 0.6}');
    buffer.writeln('dialog_blur=${newSettings['dialog_blur'] ?? 2.0}');
    buffer.writeln('dialog_opacity=${newSettings['dialog_opacity'] ?? 0.8}');
    buffer.writeln();
    buffer.writeln('[Exclusions]');
    buffer.writeln('system_excludes=${systemExcludes.join(',')}');

    try {
      File(_iniPath!).writeAsStringSync(buffer.toString());
    } catch (_) {}

    await AppConfig.setSystemExcludes(systemExcludes);

    if (newSettings.containsKey('speed_limit')) {
      await AppConfig.set('speed_limit', newSettings['speed_limit'].toString());
    }
    if (newSettings.containsKey('close_action')) {
      await AppConfig.set('close_action', newSettings['close_action'].toString());
    }
    if (newSettings.containsKey('start_with_windows')) {
      await AppConfig.setBool('start_with_windows', newSettings['start_with_windows'] == true);
    }
    if (newSettings.containsKey('start_minimized')) {
      await AppConfig.setBool('start_minimized', newSettings['start_minimized'] == true);
    }
  }
}
