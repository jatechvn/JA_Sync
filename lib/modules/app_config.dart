// lib/modules/app_config.dart
// JSON-based config reader/writer to persist settings and sync pairs

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class SyncPairConfig {
  final String id;
  final String sourcePath;
  final String targetPath;
  bool autoSync;
  String lastSyncTime;
  String conflictStrategy; // 'newer_wins', 'source_wins', 'target_wins'
  String syncMode; // 'two_way', 'one_way'
  String schedule; // 'manual', 'realtime', '15m', '1h', '12h', '24h'
  List<String> excludes;

  SyncPairConfig({
    required this.id,
    required this.sourcePath,
    required this.targetPath,
    this.autoSync = false,
    this.lastSyncTime = '',
    this.conflictStrategy = 'newer_wins',
    this.syncMode = 'two_way',
    this.schedule = 'manual',
    this.excludes = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': sourcePath,
        'target': targetPath,
        'autoSync': autoSync,
        'lastSync': lastSyncTime,
        'conflictStrategy': conflictStrategy,
        'syncMode': syncMode,
        'schedule': schedule,
        'excludes': excludes,
      };

  factory SyncPairConfig.fromJson(Map<String, dynamic> json) {
    final isAuto = json['autoSync'] ?? false;
    return SyncPairConfig(
      id: json['id'],
      sourcePath: json['source'],
      targetPath: json['target'],
      autoSync: isAuto,
      lastSyncTime: json['lastSync'] ?? '',
      conflictStrategy: json['conflictStrategy'] ?? 'newer_wins',
      syncMode: json['syncMode'] ?? 'two_way',
      schedule: json['schedule'] ?? (isAuto ? 'realtime' : 'manual'),
      excludes: json['excludes'] != null
          ? List<String>.from(json['excludes'])
          : const [],
    );
  }
}

class AppConfig {
  static String? customConfigPath;
  static String? _configPath;
  static Map<String, dynamic> _values = {};
  static List<SyncPairConfig> _pairs = [];

  /// Initialize and load configs from config.json next to the executable
  static Future<void> initialize() async {
    if (customConfigPath != null) {
      _configPath = customConfigPath;
    } else {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      _configPath = p.join(exeDir, 'config.json');
    }
    await _load();
  }

  static Future<void> _load() async {
    final file = File(_configPath!);
    if (!file.existsSync()) {
      _values = {
        'language': 'en',
        'theme': 'dark',
      };
      _pairs = [];
      await save();
      return;
    }

    try {
      final content = file.readAsStringSync();
      _values = jsonDecode(content) as Map<String, dynamic>;
      final list = _values['pairs'] as List? ?? [];
      _pairs = list
          .map((item) => SyncPairConfig.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback to defaults on corrupt config
      _values = {
        'language': 'en',
        'theme': 'dark',
      };
      _pairs = [];
    }
  }

  /// Write configuration changes to disk with automatic .bak backup
  static Future<void> save() async {
    if (_configPath == null) return;
    final file = File(_configPath!);
    if (file.existsSync()) {
      try {
        file.copySync('$_configPath.bak');
      } catch (_) {}
    }
    _values['pairs'] = _pairs.map((p) => p.toJson()).toList();
    final encoder = const JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(_values));
  }

  /// Export current configuration to a JSON file
  static Future<void> exportConfig(String destPath) async {
    if (_configPath == null) return;
    _values['pairs'] = _pairs.map((p) => p.toJson()).toList();
    final encoder = const JsonEncoder.withIndent('  ');
    final content = encoder.convert(_values);
    File(destPath).writeAsStringSync(content);
  }

  /// Import configuration from a JSON file with validation
  static Future<bool> importConfig(String srcPath) async {
    if (_configPath == null) return false;
    try {
      final file = File(srcPath);
      if (!file.existsSync()) return false;
      final content = file.readAsStringSync();
      final parsed = jsonDecode(content);
      if (parsed is! Map<String, dynamic>) return false;

      // Basic validation of fields
      if (parsed.containsKey('pairs')) {
        final list = parsed['pairs'];
        if (list is! List) return false;
        for (final item in list) {
          if (item is! Map<String, dynamic>) return false;
          if (!item.containsKey('id') || !item.containsKey('source') || !item.containsKey('target')) {
            return false;
          }
        }
      }

      // Make backup of current config
      final currentFile = File(_configPath!);
      if (currentFile.existsSync()) {
        try {
          currentFile.copySync('$_configPath.bak');
        } catch (_) {}
      }

      // Apply imported values
      _values = parsed;
      final list = _values['pairs'] as List? ?? [];
      _pairs = list
          .map((item) => SyncPairConfig.fromJson(item as Map<String, dynamic>))
          .toList();

      await save();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retrieve general key values
  static String get(String key, {String defaultValue = ''}) {
    return _values[key]?.toString() ?? defaultValue;
  }

  /// Set generic settings
  static Future<void> set(String key, String value) async {
    _values[key] = value;
    await save();
  }

  /// Retrieve general boolean key values
  static bool getBool(String key, {bool defaultValue = false}) {
    final val = _values[key];
    if (val == null) return defaultValue;
    if (val is bool) return val;
    return val.toString().toLowerCase() == 'true';
  }

  /// Set generic boolean settings
  static Future<void> setBool(String key, bool value) async {
    _values[key] = value;
    await save();
  }

  /// Get the list of all loaded sync pairs
  static List<SyncPairConfig> get pairs => _pairs;

  /// Add a sync pair configuration
  static Future<void> addPair(SyncPairConfig pair) async {
    _pairs.add(pair);
    await save();
  }

  /// Remove a sync pair configuration by id
  static Future<void> removePair(String id) async {
    _pairs.removeWhere((p) => p.id == id);
    await save();
  }

  static const List<String> defaultExcludes = [
    '.git',
    '.svn',
    '.hg',
    '.bzr',
    '.idea',
    '.vscode',
    '.vs',
    '.settings',
    'node_modules',
    '__pycache__',
    '.pytest_cache',
    '.mypy_cache',
    '.dart_tool',
    '.gradle',
    '.m2',
    '.cargo',
    '.ja_sync',
    r'$recycle.bin',
    'system volume information',
    '.trashes',
    '.fseventsd',
    '.spotlight-v100',
    '.temporaryitems',
    'build',
    'dist',
    'obj',
    'target',
    'out',
    '.next',
    '.nuxt',
    'coverage',
    'vendor',
    'ephemeral',
    '.plugin_symlinks',
    'Pods',
    'DerivedData',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
  ];

  /// Retrieve global system excludes list
  static List<String> getSystemExcludes() {
    final val = _values['system_excludes'];
    if (val is List) {
      return val.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return List<String>.from(defaultExcludes);
  }

  /// Update global system excludes list
  static Future<void> setSystemExcludes(List<String> excludes) async {
    _values['system_excludes'] = excludes;
    await save();
  }

  /// Update an existing sync pair config
  static Future<void> updatePair(SyncPairConfig updated) async {
    final idx = _pairs.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _pairs[idx] = updated;
      await save();
    }
  }
}
