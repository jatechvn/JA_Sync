// lib/modules/logic.dart
// Core business logic coordinator and two-way sync engine for JA Sync

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'constants.dart';
import 'utils.dart';
import 'app_config.dart';

final _logger = Logger('SyncLogic');

/// Represents the current runtime state of a sync pair
class SyncPairState {
  final SyncPairConfig config;
  String status; // IDLE, SCANNING, SYNCING, COMPLETED, ERROR
  double progress; // 0.0 to 1.0
  String currentFile; // The file currently being synced
  String statusMessage; // Human-readable status details

  SyncPairState({
    required this.config,
    this.status = statusIdle,
    this.progress = 0.0,
    this.currentFile = '',
    this.statusMessage = '',
  });
}

/// Action description for sync execution queue
class SyncAction {
  final String
  type; // 'copy_src_to_tgt', 'copy_tgt_to_src', 'delete_src', 'delete_tgt', 'create_dir_src', 'create_dir_tgt'
  final String relativePath;
  final String srcFullPath;
  final String destFullPath;
  final int size;

  SyncAction({
    required this.type,
    required this.relativePath,
    required this.srcFullPath,
    required this.destFullPath,
    this.size = 0,
  });
}

class SyncLogic extends ChangeNotifier {
  final List<SyncPairState> _states = [];
  final Map<String, List<StreamSubscription>> _watchers = {};
  final Map<String, Timer> _scheduledTimers = {};
  final Map<String, Timer> _watcherRetryTimers = {};
  final Set<String> _resyncPending = {};
  bool _initialized = false;

  List<SyncPairState> get states => _states;
  bool get isInitialized => _initialized;

  /// Initialize and load all configured sync pairs
  Future<void> initialize() async {
    if (_initialized) return;
    _logger.info('Initializing SyncLogic...');
    await AppConfig.initialize();

    for (final pair in AppConfig.pairs) {
      _states.add(SyncPairState(config: pair));
      _setupSchedule(pair);
    }
    _initialized = true;
    notifyListeners();
  }

  /// Get state of a pair by its ID
  SyncPairState? getState(String id) {
    return _states.where((s) => s.config.id == id).firstOrNull;
  }

  /// Add a new sync pair
  Future<void> addPair(String source, String target, String strategy) async {
    final normalizedSrc = normalizePath(source);
    final normalizedTgt = normalizePath(target);

    final newPair = SyncPairConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourcePath: normalizedSrc,
      targetPath: normalizedTgt,
      autoSync: false,
      conflictStrategy: strategy,
    );

    await AppConfig.addPair(newPair);
    _states.add(SyncPairState(config: newPair));
    notifyListeners();
    _logger.info('Added sync pair: $normalizedSrc <-> $normalizedTgt');
  }

  /// Remove a sync pair and clean up watchers/timers
  Future<void> removePair(String id) async {
    _stopSchedule(id);
    _resyncPending.remove(id);
    await AppConfig.removePair(id);
    _states.removeWhere((s) => s.config.id == id);

    // Delete manifest and recorded-deletions files
    final exeDir = _getExeDir();
    final manifestFile = File(p.join(exeDir, 'manifest_$id.json'));
    if (manifestFile.existsSync()) {
      try {
        manifestFile.deleteSync();
      } catch (_) {}
    }
    final deletionsFile = File(p.join(exeDir, 'deletions_$id.json'));
    if (deletionsFile.existsSync()) {
      try {
        deletionsFile.deleteSync();
      } catch (_) {}
    }

    notifyListeners();
    _logger.info('Removed sync pair: $id');
  }

  /// Toggle Auto-Sync for a pair (kept for compatibility)
  Future<void> toggleAutoSync(String id, bool enabled) async {
    final state = getState(id);
    if (state == null) return;

    final oldSchedule = state.config.schedule;
    state.config.autoSync = enabled;
    state.config.schedule = enabled ? 'realtime' : 'manual';
    await AppConfig.updatePair(state.config);
    _setupSchedule(state.config);
    notifyListeners();
    _logger.info('Toggled auto-sync for $id to $enabled');

    if (enabled && oldSchedule != 'realtime') {
      unawaited(syncPair(id));
    }
  }

  /// Update full settings of a pair
  Future<void> updatePairSettings(
    String id,
    String syncMode,
    String schedule,
    List<String> excludes,
  ) async {
    final state = getState(id);
    if (state == null) return;

    final oldSchedule = state.config.schedule;
    state.config.syncMode = syncMode;
    state.config.schedule = schedule;
    state.config.autoSync = (schedule == 'realtime');
    state.config.excludes = excludes;

    await AppConfig.updatePair(state.config);
    _setupSchedule(state.config);
    notifyListeners();
    _logger.info(
      'Updated pair settings for $id: syncMode=$syncMode, schedule=$schedule, excludes=$excludes',
    );

    if (schedule == 'realtime' && oldSchedule != 'realtime') {
      unawaited(syncPair(id));
    }
  }

  /// Update schedule for all sync pairs at once
  Future<void> updateAllSchedules(String schedule) async {
    for (final state in _states) {
      final oldSchedule = state.config.schedule;
      state.config.schedule = schedule;
      state.config.autoSync = (schedule == 'realtime');
      await AppConfig.updatePair(state.config);
      _setupSchedule(state.config);
      if (schedule == 'realtime' && oldSchedule != 'realtime') {
        unawaited(syncPair(state.config.id));
      }
    }
    notifyListeners();
    _logger.info('Updated all sync pair schedules to: $schedule');
  }

  /// Setup scheduling timers or real-time watcher
  void _setupSchedule(SyncPairConfig pair) {
    _stopSchedule(pair.id);

    // Always run a lightweight watcher so genuine deletions are confirmed
    // (see onEvent's delete-recording), regardless of schedule. Only
    // 'realtime' pairs use it to auto-trigger a debounced sync; manual and
    // timed pairs still rely on a manual click / the periodic timer below,
    // but by then any deletion made while the app was running is recorded.
    _startWatcher(pair);

    if (pair.schedule != 'realtime' && pair.schedule != 'manual') {
      Duration duration;
      switch (pair.schedule) {
        case '15m':
          duration = const Duration(minutes: 15);
          break;
        case '1h':
          duration = const Duration(hours: 1);
          break;
        case '12h':
          duration = const Duration(hours: 12);
          break;
        case '24h':
          duration = const Duration(hours: 24);
          break;
        default:
          return;
      }
      _scheduledTimers[pair.id] = Timer.periodic(duration, (_) {
        syncPair(pair.id);
      });
      _logger.info(
        'Scheduled periodic sync for ${pair.id} every ${pair.schedule}',
      );
    }
  }

  /// Stop scheduling timers and watchers
  void _stopSchedule(String id) {
    _stopWatcher(id);
    final timer = _scheduledTimers.remove(id);
    if (timer != null) {
      timer.cancel();
      _logger.info('Cancelled scheduled sync timer for $id');
    }
  }

  /// Exclusions matcher
  bool _isExcluded(String relativePath, List<String> patterns) {
    if (patterns.isEmpty) return false;
    final pathLower = relativePath.toLowerCase();
    for (final pattern in patterns) {
      final clean = pattern.trim().toLowerCase();
      if (clean.isEmpty) continue;

      if (clean.startsWith('*.')) {
        final ext = clean.substring(1);
        if (pathLower.endsWith(ext)) return true;
      } else if (pathLower.contains(clean)) {
        return true;
      }
    }
    return false;
  }

  /// Update conflict strategy for a pair
  Future<void> updateConflictStrategy(String id, String strategy) async {
    final state = getState(id);
    if (state == null) return;

    state.config.conflictStrategy = strategy;
    await AppConfig.updatePair(state.config);
    notifyListeners();
  }

  void _scheduleWatcherRetry(SyncPairConfig pair) {
    _watcherRetryTimers[pair.id]?.cancel();
    _watcherRetryTimers[pair.id] = Timer(const Duration(seconds: 15), () {
      final state = getState(pair.id);
      if (state != null && state.config.schedule == 'realtime') {
        _logger.info(
          'Retrying starting directory watcher for pair ${pair.id}...',
        );
        _startWatcher(pair);
      }
    });
  }

  /// Starts folder watchers for a pair
  void _startWatcher(SyncPairConfig pair) {
    _stopWatcher(pair.id);

    final srcDir = Directory(pair.sourcePath);
    final tgtDir = Directory(pair.targetPath);

    try {
      if (!srcDir.existsSync() || !tgtDir.existsSync()) {
        _logger.warning(
          'Cannot start watcher for pair ${pair.id}: source or target path does not exist',
        );
        _scheduleWatcherRetry(pair);
        return;
      }
    } catch (e) {
      _logger.warning(
        'Failed directory existence check for watcher on pair ${pair.id}: $e',
      );
      _scheduleWatcherRetry(pair);
      return;
    }

    Timer? debounceTimer;
    void onEvent(FileSystemEvent event) {
      // Ignore log files, hidden config directories, build junk, and system files
      if (isSystemIgnored(event.path)) {
        return;
      }
      _logger.info(
        '[Watcher] Change detected in pair ${pair.id}: ${event.path}',
      );

      if (event is FileSystemDeleteEvent) {
        final normPath = p.normalize(event.path).toLowerCase();
        final normSource = p.normalize(pair.sourcePath).toLowerCase();
        final isSource = normPath.startsWith(normSource);
        final rootPath = isSource ? pair.sourcePath : pair.targetPath;
        final relPath = p
            .relative(event.path, from: rootPath)
            .replaceAll(r'\', '/');

        _recordDeletion(pair.id, relPath, isSource);
      }

      // Only realtime pairs auto-trigger a sync on change; manual/timed
      // pairs just needed the deletion recorded above and will pick it up
      // on their next manual click or scheduled tick.
      if (pair.schedule != 'realtime') return;

      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(seconds: 4), () {
        syncPair(pair.id);
      });
    }

    try {
      final sub1 = srcDir
          .watch(recursive: true)
          .listen(
            onEvent,
            onError: (e) {
              _logger.warning(
                'Watcher error on source for pair ${pair.id}: $e',
              );
              _scheduleWatcherRetry(pair);
            },
            onDone: () {
              _logger.info('Watcher on source for pair ${pair.id} closed.');
              _scheduleWatcherRetry(pair);
            },
          );
      final sub2 = tgtDir
          .watch(recursive: true)
          .listen(
            onEvent,
            onError: (e) {
              _logger.warning(
                'Watcher error on target for pair ${pair.id}: $e',
              );
              _scheduleWatcherRetry(pair);
            },
            onDone: () {
              _logger.info('Watcher on target for pair ${pair.id} closed.');
              _scheduleWatcherRetry(pair);
            },
          );

      _watchers[pair.id] = [sub1, sub2];
      _logger.info('Started watcher for sync pair: ${pair.id}');
    } catch (e) {
      _logger.severe('Failed to start watcher for pair ${pair.id}: $e');
      _scheduleWatcherRetry(pair);
    }
  }

  /// Stops folder watchers for a pair
  void _stopWatcher(String id) {
    final subs = _watchers.remove(id);
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
      _logger.info('Stopped watcher for sync pair: $id');
    }
    _watcherRetryTimers.remove(id)?.cancel();
  }

  /// Re-runs sync for [id] if a request arrived while it was busy
  void _runPendingResyncIfAny(String id) {
    if (_resyncPending.remove(id)) {
      _logger.info('Running queued follow-up sync for $id');
      unawaited(syncPair(id));
    }
  }

  /// Synchronize all loaded pairs
  Future<void> syncAll() async {
    _logger.info('=== Sync All Started ===');
    final activeIds = _states.map((s) => s.config.id).toList();
    for (final id in activeIds) {
      await syncPair(id);
    }
    _logger.info('=== Sync All Finished ===');
  }

  /// Scans both sides, loads the manifest/deletion records, and returns the
  /// list of pending actions -- without executing them or touching any
  /// on-disk state. Shared by syncPair() (real run) and previewSync()
  /// (dry-run) so the two can never drift apart.
  Future<List<SyncAction>> _scanAndCompare(SyncPairState state) async {
    final sourceFiles = await scanDirectory(state.config.sourcePath);
    final targetFiles = await scanDirectory(state.config.targetPath);

    final excludes = state.config.excludes;
    if (excludes.isNotEmpty) {
      sourceFiles.removeWhere((k, v) => _isExcluded(k, excludes));
      targetFiles.removeWhere((k, v) => _isExcluded(k, excludes));
    }

    final exeDir = _getExeDir();
    final manifestFile = File(p.join(exeDir, 'manifest_${state.config.id}.json'));
    Map<String, FileInfo> manifestFiles = {};

    if (manifestFile.existsSync()) {
      try {
        final content = manifestFile.readAsStringSync();
        final Map<String, dynamic> json = jsonDecode(content);
        json.forEach((k, v) {
          if (isSystemIgnored(k)) return;
          if (excludes.isEmpty || !_isExcluded(k, excludes)) {
            manifestFiles[k] = FileInfo.fromJson(v as Map<String, dynamic>);
          }
        });
      } catch (e) {
        _logger.warning(
          'Failed to parse manifest for pair ${state.config.id}: $e. Performing fallback comparison.',
        );
      }
    }

    final deletionsFile = File(
      p.join(exeDir, 'deletions_${state.config.id}.json'),
    );
    final deletions = _loadDeletions(deletionsFile);

    return _compareDirectories(
      sourceFiles: sourceFiles,
      targetFiles: targetFiles,
      manifestFiles: manifestFiles,
      srcRoot: state.config.sourcePath,
      tgtRoot: state.config.targetPath,
      config: state.config,
      deletions: deletions,
    );
  }

  /// Dry-run: computes what a real sync would do for [id] without changing
  /// any file, manifest, or deletion record. Returns null if the pair
  /// doesn't exist, either folder is currently inaccessible, or the scan
  /// fails -- distinct from an empty list, which means "no changes".
  Future<List<SyncAction>?> previewSync(String id) async {
    final state = getState(id);
    if (state == null) return null;

    try {
      final srcDir = Directory(state.config.sourcePath);
      final tgtDir = Directory(state.config.targetPath);
      if (!await srcDir.exists() || !await tgtDir.exists()) return null;
      return await _scanAndCompare(state);
    } catch (e) {
      _logger.warning('Preview failed for pair $id: $e');
      return null;
    }
  }

  /// Runs Bidirectional Sync for a single pair
  Future<void> syncPair(String id) async {
    final state = getState(id);
    if (state == null) return;

    if (state.status == statusScanning || state.status == statusSyncing) {
      _logger.info(
        'Sync pair $id is already busy: ${state.status}. Queuing a follow-up sync.',
      );
      _resyncPending.add(id);
      return;
    }
    _resyncPending.remove(id);

    _logger.info('=== START SYNC PAIR $id ===');
    _logger.info('Source: ${state.config.sourcePath}');
    _logger.info('Target: ${state.config.targetPath}');

    state.status = statusScanning;
    state.progress = 0.0;
    state.currentFile = '';
    state.statusMessage = 'Scanning files...';
    notifyListeners();

    try {
      final srcDir = Directory(state.config.sourcePath);
      final tgtDir = Directory(state.config.targetPath);

      bool srcExists = false;
      bool tgtExists = false;
      try {
        srcExists = srcDir.existsSync();
        tgtExists = tgtDir.existsSync();
      } catch (e) {
        state.status = statusError;
        state.statusMessage = 'Folder access error: $e';
        notifyListeners();
        return;
      }

      if (!srcExists || !tgtExists) {
        state.status = statusError;
        state.statusMessage = 'Source or target folder does not exist.';
        notifyListeners();
        return;
      }

      // 1-3. Scan both sides, load manifest/deletions, and compare
      final exeDir = _getExeDir();
      final manifestFile = File(p.join(exeDir, 'manifest_$id.json'));
      final deletionsFile = File(p.join(exeDir, 'deletions_$id.json'));
      final actions = await _scanAndCompare(state);

      _logger.info('Found ${actions.length} sync actions to execute.');

      if (actions.isEmpty) {
        _logger.info('No changes detected. Sync complete.');
        state.status = statusCompleted;
        state.progress = 1.0;
        state.statusMessage = 'Already up to date';

        state.config.lastSyncTime = formatTimestampDisplay();
        await AppConfig.updatePair(state.config);

        // Write fresh manifest anyway
        final freshSourceFiles = await scanDirectory(state.config.sourcePath);
        _writeManifest(manifestFile, freshSourceFiles);
        notifyListeners();

        // Reset status to IDLE after a short delay
        Timer(const Duration(seconds: 4), () {
          if (state.status == statusCompleted) {
            state.status = statusIdle;
            state.statusMessage = '';
            notifyListeners();
          }
        });
        _runPendingResyncIfAny(id);
        return;
      }

      // 4. Execute Actions
      state.status = statusSyncing;
      state.statusMessage = 'Syncing...';
      notifyListeners();

      // Calculate total size to sync for progress tracking
      int totalSize = actions.fold(0, (sum, item) => sum + item.size);
      int processedSizeBeforeAction = 0;
      int completedActionsCount = 0;
      int failedActionsCount = 0;

      final List<Map<String, String>> pendingHistory = [];
      int lastNotifyTime = 0;

      for (final action in actions) {
        state.currentFile = action.relativePath;
        state.statusMessage = _getActionLabel(action);

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastNotifyTime > 150) {
          notifyListeners();
          lastNotifyTime = nowMs;
          await Future.delayed(Duration.zero);
        }

        try {
          await _executeAction(action, (bytesWrittenInCurrentFile) {
            final currentProcessedSize =
                processedSizeBeforeAction + bytesWrittenInCurrentFile;
            if (totalSize > 0) {
              state.progress = currentProcessedSize / totalSize;
            }
            final cbNowMs = DateTime.now().millisecondsSinceEpoch;
            if (cbNowMs - lastNotifyTime > 150) {
              notifyListeners();
              lastNotifyTime = cbNowMs;
            }
          }, pendingHistory);
        } catch (e) {
          _logger.warning(
            'Failed to execute sync action [${action.type}] for ${action.relativePath}: $e',
          );
          failedActionsCount++;
        }

        processedSizeBeforeAction += action.size;
        completedActionsCount++;

        if (totalSize > 0) {
          state.progress = processedSizeBeforeAction / totalSize;
        } else {
          state.progress = completedActionsCount / actions.length;
        }
      }

      // Save pending history in a single batch file operation
      if (pendingHistory.isNotEmpty) {
        await _saveHistoryEntriesBatch(pendingHistory);
      }

      // Clear successfully processed deletions from the record. Reload from
      // disk first: the watcher may have recorded new deletions on disk
      // while this sync was running its (possibly long) action loop, and
      // writing back the stale in-memory snapshot loaded at step 2.5 would
      // silently drop them.
      final currentDeletions = _loadDeletions(deletionsFile);
      for (final action in actions) {
        if (action.type == 'delete_tgt') {
          currentDeletions.deletedOnSource.remove(action.relativePath);
        } else if (action.type == 'delete_src') {
          currentDeletions.deletedOnTarget.remove(action.relativePath);
        }
      }
      _saveDeletions(deletionsFile, currentDeletions);

      // 5. Post-sync operations: clean up empty directories that were deleted
      await _cleanEmptyDirectories(
        state.config.sourcePath,
        state.config.sourcePath,
      );
      await _cleanEmptyDirectories(
        state.config.targetPath,
        state.config.targetPath,
      );

      // 6. Rescan source files to build the definitive new manifest
      final finalSourceFiles = await scanDirectory(state.config.sourcePath);
      _writeManifest(manifestFile, finalSourceFiles);

      state.status = statusCompleted;
      state.progress = 1.0;
      if (failedActionsCount > 0) {
        state.statusMessage =
            'Sync completed with $failedActionsCount skipped/failed files';
      } else {
        state.statusMessage =
            'Sync completed successfully! (${actions.length} changes)';
      }
      state.currentFile = '';

      state.config.lastSyncTime = formatTimestampDisplay();
      await AppConfig.updatePair(state.config);

      _writeHistoryLog(
        'SYNC',
        state.config.sourcePath,
        state.config.targetPath,
        'Executed ${actions.length} actions (failed: $failedActionsCount)',
      );

      notifyListeners();

      // Reset to IDLE after a few seconds
      Timer(const Duration(seconds: 4), () {
        if (state.status == statusCompleted) {
          state.status = statusIdle;
          state.statusMessage = '';
          notifyListeners();
        }
      });
      _runPendingResyncIfAny(id);
    } catch (e, stack) {
      _logger.severe('Sync error on pair $id: $e', e, stack);
      state.status = statusError;
      state.statusMessage = 'Error: $e';
      _writeHistoryLog(
        'ERROR',
        state.config.sourcePath,
        state.config.targetPath,
        e.toString(),
      );
      await _addHistoryEntry(
        action: 'ERROR',
        file: 'Pair $id',
        details: e.toString(),
        status: 'FAILED',
      );
      notifyListeners();
    }
  }

  /// Comparison algorithm for synchronization (supports one-way mirror and two-way strategies)
  List<SyncAction> _compareDirectories({
    required Map<String, FileInfo> sourceFiles,
    required Map<String, FileInfo> targetFiles,
    required Map<String, FileInfo> manifestFiles,
    required String srcRoot,
    required String tgtRoot,
    required SyncPairConfig config,
    required PairDeletions deletions,
  }) {
    final strategy = config.conflictStrategy;
    final List<SyncAction> actions = [];

    // Safeguard: If target is completely empty, we should not delete anything from source.
    // Likewise, if source is completely empty, we should not delete anything from target.
    // In these cases, we treat the manifest as empty so that it performs a clean copy of files instead of deleting them.
    bool targetIsEmpty = targetFiles.isEmpty;
    bool sourceIsEmpty = sourceFiles.isEmpty;
    Map<String, FileInfo> activeManifest = manifestFiles;
    if (targetIsEmpty || sourceIsEmpty) {
      if (manifestFiles.isNotEmpty) {
        activeManifest = {};
        _logger.warning(
          'Safeguard triggered: One of the sync directories is completely empty. Ignoring manifest to prevent accidental deletions.',
        );
      }
    }

    final Set<String> allPaths = {};
    allPaths.addAll(sourceFiles.keys);
    allPaths.addAll(targetFiles.keys);
    allPaths.addAll(activeManifest.keys);

    if (config.syncMode == 'one_way') {
      // One-Way Mirror comparison (Source is master)
      for (final path in allPaths) {
        if (isSystemIgnored(path)) continue;
        final src = sourceFiles[path];
        final tgt = targetFiles[path];

        if ((src != null && src.isInaccessible) ||
            (tgt != null && tgt.isInaccessible)) {
          _logger.warning(
            'Skipping file $path because it is locked or inaccessible on one of the sides.',
          );
          continue;
        }

        final srcFull = p.normalize(p.join(srcRoot, path));
        final tgtFull = p.normalize(p.join(tgtRoot, path));

        if (src != null) {
          if (tgt == null) {
            // New in source -> copy to target
            actions.add(
              SyncAction(
                type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
                relativePath: path,
                srcFullPath: srcFull,
                destFullPath: tgtFull,
                size: src.size,
              ),
            );
          } else {
            // Exists in both -> compare size and mtime
            final changed =
                src.isDirectory != tgt.isDirectory ||
                src.size != tgt.size ||
                src.mtime.difference(tgt.mtime).abs().inSeconds > 2;
            if (changed) {
              actions.add(
                SyncAction(
                  type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
                  relativePath: path,
                  srcFullPath: srcFull,
                  destFullPath: tgtFull,
                  size: src.size,
                ),
              );
            }
          }
        } else {
          // Does not exist in source, but exists in target -> delete from target
          if (tgt != null) {
            actions.add(
              SyncAction(
                type: 'delete_tgt',
                relativePath: path,
                srcFullPath: '',
                destFullPath: tgtFull,
              ),
            );
          }
        }
      }
      return actions;
    }

    bool hasChanged(FileInfo? current, FileInfo? previous) {
      if (previous == null && current == null) return false;
      if (previous == null || current == null) return true; // Added or deleted
      if (current.isDirectory != previous.isDirectory) return true;
      if (current.size != previous.size) return true;
      // Compare mtimes (allow up to 2 seconds precision tolerance due to FAT32/NTFS variations)
      return current.mtime.difference(previous.mtime).abs().inSeconds > 2;
    }

    for (final path in allPaths) {
      if (isSystemIgnored(path)) continue;
      final src = sourceFiles[path];
      final tgt = targetFiles[path];
      final man = activeManifest[path];

      if ((src != null && src.isInaccessible) ||
          (tgt != null && tgt.isInaccessible)) {
        _logger.warning(
          'Skipping file $path because it is locked or inaccessible on one of the sides.',
        );
        continue;
      }

      final srcChanged = hasChanged(src, man);
      final tgtChanged = hasChanged(tgt, man);

      final srcFull = p.normalize(p.join(srcRoot, path));
      final tgtFull = p.normalize(p.join(tgtRoot, path));

      // CASE 1: Changed on both sides -> Conflict!
      if (srcChanged && tgtChanged) {
        _logger.info('Conflict detected on file: $path');
        if (strategy == 'source_wins') {
          if (src == null) {
            final wasDeleted = _isPathDeleted(path, deletions.deletedOnSource);
            if (wasDeleted) {
              actions.add(
                SyncAction(
                  type: 'delete_tgt',
                  relativePath: path,
                  srcFullPath: '',
                  destFullPath: tgtFull,
                ),
              );
            } else {
              if (tgt != null) {
                actions.add(
                  SyncAction(
                    type: tgt.isDirectory
                        ? 'create_dir_src'
                        : 'copy_tgt_to_src',
                    relativePath: path,
                    srcFullPath: tgtFull,
                    destFullPath: srcFull,
                    size: tgt.size,
                  ),
                );
              }
            }
          } else {
            actions.add(
              SyncAction(
                type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
                relativePath: path,
                srcFullPath: srcFull,
                destFullPath: tgtFull,
                size: src.size,
              ),
            );
          }
        } else if (strategy == 'target_wins') {
          if (tgt == null) {
            final wasDeleted = _isPathDeleted(path, deletions.deletedOnTarget);
            if (wasDeleted) {
              actions.add(
                SyncAction(
                  type: 'delete_src',
                  relativePath: path,
                  srcFullPath: '',
                  destFullPath: srcFull,
                ),
              );
            } else {
              if (src != null) {
                actions.add(
                  SyncAction(
                    type: src.isDirectory
                        ? 'create_dir_tgt'
                        : 'copy_src_to_tgt',
                    relativePath: path,
                    srcFullPath: srcFull,
                    destFullPath: tgtFull,
                    size: src.size,
                  ),
                );
              }
            }
          } else {
            actions.add(
              SyncAction(
                type: tgt.isDirectory ? 'create_dir_src' : 'copy_tgt_to_src',
                relativePath: path,
                srcFullPath: tgtFull,
                destFullPath: srcFull,
                size: tgt.size,
              ),
            );
          }
        } else {
          // Default: newer_wins
          if (src == null && tgt != null) {
            // Deleted on source, modified/added on target -> Re-copy from target to source
            actions.add(
              SyncAction(
                type: tgt.isDirectory ? 'create_dir_src' : 'copy_tgt_to_src',
                relativePath: path,
                srcFullPath: tgtFull,
                destFullPath: srcFull,
                size: tgt.size,
              ),
            );
          } else if (tgt == null && src != null) {
            // Deleted on target, modified/added on source -> Re-copy from source to target
            actions.add(
              SyncAction(
                type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
                relativePath: path,
                srcFullPath: srcFull,
                destFullPath: tgtFull,
                size: src.size,
              ),
            );
          } else if (src != null && tgt != null) {
            // Both present, choose newer
            if (src.mtime.isAfter(tgt.mtime)) {
              actions.add(
                SyncAction(
                  type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
                  relativePath: path,
                  srcFullPath: srcFull,
                  destFullPath: tgtFull,
                  size: src.size,
                ),
              );
            } else {
              actions.add(
                SyncAction(
                  type: tgt.isDirectory ? 'create_dir_src' : 'copy_tgt_to_src',
                  relativePath: path,
                  srcFullPath: tgtFull,
                  destFullPath: srcFull,
                  size: tgt.size,
                ),
              );
            }
          }
        }
      }
      // CASE 2: Changed only on source
      else if (srcChanged) {
        if (src == null) {
          // Deleted on source -> Delete on target
          final wasDeleted = _isPathDeleted(path, deletions.deletedOnSource);
          if (wasDeleted) {
            actions.add(
              SyncAction(
                type: 'delete_tgt',
                relativePath: path,
                srcFullPath: '',
                destFullPath: tgtFull,
              ),
            );
          } else {
            if (tgt != null) {
              actions.add(
                SyncAction(
                  type: tgt.isDirectory ? 'create_dir_src' : 'copy_tgt_to_src',
                  relativePath: path,
                  srcFullPath: tgtFull,
                  destFullPath: srcFull,
                  size: tgt.size,
                ),
              );
            }
          }
        } else {
          // Added or modified on source -> Copy to target
          actions.add(
            SyncAction(
              type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
              relativePath: path,
              srcFullPath: srcFull,
              destFullPath: tgtFull,
              size: src.size,
            ),
          );
        }
      }
      // CASE 3: Changed only on target
      else if (tgtChanged) {
        if (tgt == null) {
          // Deleted on target -> Delete on source
          final wasDeleted = _isPathDeleted(path, deletions.deletedOnTarget);
          if (wasDeleted) {
            actions.add(
              SyncAction(
                type: 'delete_src',
                relativePath: path,
                srcFullPath: '',
                destFullPath: srcFull,
              ),
            );
          } else {
            if (src != null) {
              actions.add(
                SyncAction(
                  type: src.isDirectory ? 'create_dir_tgt' : 'copy_src_to_tgt',
                  relativePath: path,
                  srcFullPath: srcFull,
                  destFullPath: tgtFull,
                  size: src.size,
                ),
              );
            }
          }
        } else {
          // Added or modified on target -> Copy to source
          actions.add(
            SyncAction(
              type: tgt.isDirectory ? 'create_dir_src' : 'copy_tgt_to_src',
              relativePath: path,
              srcFullPath: tgtFull,
              destFullPath: srcFull,
              size: tgt.size,
            ),
          );
        }
      }
    }

    return actions;
  }

  /// Get action display label
  String _getActionLabel(SyncAction action) {
    final filename = p.basename(action.relativePath);
    switch (action.type) {
      case 'copy_src_to_tgt':
      case 'copy_tgt_to_src':
        return 'Copying file: $filename (${formatFileSize(action.size)})';
      case 'delete_src':
      case 'delete_tgt':
        return 'Deleting: $filename';
      case 'create_dir_src':
      case 'create_dir_tgt':
        return 'Creating folder: $filename';
      default:
        return 'Syncing...';
    }
  }

  /// Executes a single synchronization action
  Future<void> _executeAction(
    SyncAction action,
    Function(int bytesWritten) onProgress,
    List<Map<String, String>> pendingHistory,
  ) async {
    try {
      if (action.type == 'copy_src_to_tgt' ||
          action.type == 'copy_tgt_to_src') {
        await _copyFileWithProgress(
          action.srcFullPath,
          action.destFullPath,
          onProgress,
        );
        pendingHistory.add({
          'time': formatTimestampDisplay(),
          'action': 'COPY',
          'file': action.relativePath,
          'details': action.type == 'copy_src_to_tgt'
              ? 'Source -> Target'
              : 'Target -> Source',
          'status': 'SUCCESS',
        });
      } else if (action.type == 'create_dir_src' ||
          action.type == 'create_dir_tgt') {
        final dir = Directory(action.destFullPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        _logger.fine('Created directory: ${action.destFullPath}');
      } else if (action.type == 'delete_src' || action.type == 'delete_tgt') {
        final file = File(action.destFullPath);
        if (await file.exists()) {
          await file.delete();
          _logger.fine('Deleted file: ${action.destFullPath}');
          pendingHistory.add({
            'time': formatTimestampDisplay(),
            'action': 'DELETE',
            'file': action.relativePath,
            'details': action.type == 'delete_src'
                ? 'From Source'
                : 'From Target',
            'status': 'SUCCESS',
          });
        } else {
          final dir = Directory(action.destFullPath);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
            _logger.fine(
              'Deleted directory recursively: ${action.destFullPath}',
            );
          }
        }
      }
    } catch (e) {
      _logger.warning(
        'Failed to execute sync action [${action.type}] for ${action.relativePath}: $e',
      );
      pendingHistory.add({
        'time': formatTimestampDisplay(),
        'action': action.type.startsWith('copy') ? 'COPY' : 'DELETE',
        'file': action.relativePath,
        'details': e.toString(),
        'status': 'FAILED',
      });
      rethrow;
    }
  }

  /// Copies a file asynchronously in chunks with atomic temporary file writing, retry resilience, and speed limiting
  Future<void> _copyFileWithProgress(
    String srcPath,
    String destPath,
    Function(int bytesWritten) onProgress,
  ) async {
    const maxRetries = 3;
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      attempt++;
      final tempPath = '$destPath.ja_sync_tmp';
      final backupPath = '$destPath.ja_sync_bak';
      final tempFile = File(tempPath);
      final backupFile = File(backupPath);
      final destFile = File(destPath);
      final srcFile = File(srcPath);
      bool backedUp = false;

      try {
        // Ensure destination parent directory exists
        await tempFile.parent.create(recursive: true);

        // Remove old stale temp/backup files if present
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
        if (await backupFile.exists()) {
          try {
            await backupFile.delete();
          } catch (_) {}
        }

        final destSink = tempFile.openWrite(mode: FileMode.write);
        try {
          final srcStream = srcFile.openRead();
          int bytesWritten = 0;
          final limitString = AppConfig.get('speed_limit', defaultValue: '0');
          final speedLimitMB = int.tryParse(limitString) ?? 0;
          final maxBytesPerSecond = speedLimitMB * 1024 * 1024;
          final stopwatch = Stopwatch()..start();

          await for (final chunk in srcStream) {
            destSink.add(chunk);
            bytesWritten += chunk.length;
            onProgress(bytesWritten);

            if (maxBytesPerSecond > 0) {
              final elapsedMs = stopwatch.elapsedMilliseconds;
              final expectedMs = (bytesWritten / maxBytesPerSecond) * 1000;
              if (expectedMs > elapsedMs) {
                final delayMs = (expectedMs - elapsedMs).round();
                await Future.delayed(Duration(milliseconds: delayMs));
              }
            } else {
              await Future.delayed(Duration.zero);
            }
          }
        } finally {
          await destSink.close();
        }

        // Verify source and temp file size
        final srcStat = await srcFile.stat();
        final tempStat = await tempFile.stat();

        if (srcStat.size != tempStat.size) {
          throw FileSystemException(
            'Copy size mismatch: expected ${srcStat.size} bytes, wrote ${tempStat.size} bytes',
            tempPath,
          );
        }

        // Atomically replace target file: move the existing file aside
        // first rather than deleting it outright, so a failed rename can
        // never leave the destination missing.
        if (await destFile.exists()) {
          await destFile.rename(backupPath);
          backedUp = true;
        }
        await tempFile.rename(destPath);

        // Preserve exact modification timestamp
        final finalDestFile = File(destPath);
        await finalDestFile.setLastModified(srcStat.modified);

        // Success: the new file is safely in place, drop the backup
        if (backedUp && await backupFile.exists()) {
          try {
            await backupFile.delete();
          } catch (_) {}
        }

        _logger.fine('Copied atomically: $srcPath -> $destPath');
        return; // Success!
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // If we moved the original file aside but never completed the
        // swap, restore it so the destination isn't left missing.
        if (backedUp && !await destFile.exists() && await backupFile.exists()) {
          try {
            await backupFile.rename(destPath);
          } catch (_) {}
        }

        // Clean up temp file on failure
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }

        _logger.warning(
          'Copy attempt $attempt/$maxRetries failed for $srcPath: $e',
        );
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }

    if (lastException != null) {
      throw lastException;
    }
  }

  /// Cleans up empty subfolders recursively
  Future<void> _cleanEmptyDirectories(String dirPath, String rootPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final relPath = p.relative(entity.path, from: rootPath);
          final uniformKey = relPath.replaceAll(r'\', '/');
          if (isSystemIgnored(uniformKey)) continue;

          await Future.delayed(Duration.zero); // Yield to event loop
          await _cleanEmptyDirectories(entity.path, rootPath);
        }
      }

      // Re-read and check if it has become empty now
      if (dirPath != rootPath && await dir.list(followLinks: false).isEmpty) {
        await dir.delete();
        _logger.info('Deleted empty directory: ${dir.path}');
      }
    } catch (_) {}
  }

  /// Write the manifest file
  void _writeManifest(File file, Map<String, FileInfo> data) {
    try {
      final Map<String, dynamic> jsonMap = {};
      data.forEach((k, v) {
        jsonMap[k] = v.toJson();
      });
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(jsonMap),
      );
    } catch (e) {
      _logger.severe('Failed to write manifest file: $e');
    }
  }

  /// Write sync history log
  void _writeHistoryLog(
    String actionType,
    String source,
    String target,
    String details,
  ) {
    try {
      final exeDir = _getExeDir();
      final logDir = Directory(p.join(exeDir, 'logs'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final logFile = File(p.join(logDir.path, defaultHistoryLogFile));
      final buffer = StringBuffer();
      buffer.writeln('[${formatTimestampDisplay()}] $actionType');
      buffer.writeln('  Source: $source');
      buffer.writeln('  Target: $target');
      buffer.writeln('  Details: $details');
      buffer.writeln('---');
      logFile.writeAsStringSync(buffer.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  /// Write structured JSON sync history entries in batch
  Future<void> _saveHistoryEntriesBatch(
    List<Map<String, String>> newEntries,
  ) async {
    if (newEntries.isEmpty) return;
    try {
      final exeDir = _getExeDir();
      final logDir = Directory(p.join(exeDir, 'logs'));
      if (!logDir.existsSync()) {
        await logDir.create(recursive: true);
      }

      final historyFile = File(p.join(logDir.path, 'sync_history.json'));
      List<dynamic> entries = [];
      if (await historyFile.exists()) {
        try {
          final content = await historyFile.readAsString();
          entries = jsonDecode(content) as List<dynamic>;
        } catch (_) {}
      }

      // Add all new entries in reverse order so newest is top
      entries.insertAll(0, newEntries.reversed);
      if (entries.length > 200) {
        entries = entries.sublist(0, 200);
      }

      await historyFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(entries),
      );
    } catch (e) {
      _logger.warning('Failed to save history batch: $e');
    }
  }

  /// Write single structured JSON sync history entry
  Future<void> _addHistoryEntry({
    required String action,
    required String file,
    required String details,
    required String status,
  }) async {
    await _saveHistoryEntriesBatch([
      {
        'time': formatTimestampDisplay(),
        'action': action,
        'file': file,
        'details': details,
        'status': status,
      },
    ]);
  }

  String _getExeDir() {
    if (AppConfig.customConfigPath != null) {
      return p.dirname(AppConfig.customConfigPath!);
    }
    return p.dirname(Platform.resolvedExecutable);
  }

  @override
  void dispose() {
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    for (final timer in _watcherRetryTimers.values) {
      timer.cancel();
    }
    for (final subs in _watchers.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    super.dispose();
  }

  PairDeletions _loadDeletions(File file) {
    if (!file.existsSync()) {
      return PairDeletions(deletedOnSource: {}, deletedOnTarget: {});
    }
    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content);
      final srcList = List<String>.from(json['deletedOnSource'] ?? []);
      final tgtList = List<String>.from(json['deletedOnTarget'] ?? []);
      return PairDeletions(
        deletedOnSource: srcList.toSet(),
        deletedOnTarget: tgtList.toSet(),
      );
    } catch (e) {
      _logger.warning('Failed to load deletions file: $e');
      return PairDeletions(deletedOnSource: {}, deletedOnTarget: {});
    }
  }

  void _saveDeletions(File file, PairDeletions deletions) {
    try {
      final json = {
        'deletedOnSource': deletions.deletedOnSource.toList(),
        'deletedOnTarget': deletions.deletedOnTarget.toList(),
      };
      file.writeAsStringSync(jsonEncode(json));
    } catch (e) {
      _logger.warning('Failed to save deletions file: $e');
    }
  }

  void _recordDeletion(String pairId, String relPath, bool isSource) {
    final exeDir = _getExeDir();
    final file = File(p.join(exeDir, 'deletions_$pairId.json'));
    final deletions = _loadDeletions(file);
    if (isSource) {
      deletions.deletedOnSource.add(relPath);
    } else {
      deletions.deletedOnTarget.add(relPath);
    }
    _saveDeletions(file, deletions);
  }

  bool _isPathDeleted(String path, Set<String> deletedPaths) {
    if (deletedPaths.contains(path)) return true;
    for (final deleted in deletedPaths) {
      if (path.startsWith('$deleted/')) {
        return true;
      }
    }
    return false;
  }
}

class PairDeletions {
  final Set<String> deletedOnSource;
  final Set<String> deletedOnTarget;

  PairDeletions({required this.deletedOnSource, required this.deletedOnTarget});
}
