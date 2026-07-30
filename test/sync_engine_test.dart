import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ja_sync/modules/app_config.dart';
import 'package:ja_sync/modules/logic.dart';
import 'package:ja_sync/modules/utils.dart';

void main() {
  late Directory tempDir;
  late Directory sourceDir;
  late Directory targetDir;
  late File configFile;

  setUp(() async {
    // Set up temp directories
    tempDir = await Directory.systemTemp.createTemp('ja_sync_test_');
    sourceDir = Directory(p.join(tempDir.path, 'source'));
    await sourceDir.create();
    targetDir = Directory(p.join(tempDir.path, 'target'));
    await targetDir.create();

    // Setup config file
    configFile = File(p.join(tempDir.path, 'config.json'));
    AppConfig.customConfigPath = configFile.path;
    await AppConfig.initialize();
  });

  tearDown(() async {
    AppConfig.customConfigPath = null;
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('One-Way Mirror Sync Mode with Exclude Filter', () async {
    // 1. Setup Source files
    final srcFileA = File(p.join(sourceDir.path, 'a.txt'));
    await srcFileA.writeAsString('Hello Source A');
    await srcFileA.setLastModified(DateTime.now().subtract(const Duration(minutes: 5)));

    final srcFileB = File(p.join(sourceDir.path, 'b.tmp'));
    await srcFileB.writeAsString('Temporary Source B');

    final srcSubDir = Directory(p.join(sourceDir.path, 'sub'));
    await srcSubDir.create();
    final srcFileC = File(p.join(srcSubDir.path, 'c.txt'));
    await srcFileC.writeAsString('Sub folder file C');

    // 2. Setup Target files (older a.txt, and extra d.txt)
    final tgtFileA = File(p.join(targetDir.path, 'a.txt'));
    await tgtFileA.writeAsString('Hello Target A (old)');
    await tgtFileA.setLastModified(DateTime.now().subtract(const Duration(minutes: 10)));

    final tgtFileD = File(p.join(targetDir.path, 'd.txt'));
    await tgtFileD.writeAsString('Extra target file');

    // 3. Initialize SyncLogic and add the pair
    final logic = SyncLogic();
    await logic.initialize();
    await logic.addPair(sourceDir.path, targetDir.path, 'newer_wins');

    expect(logic.states.length, 1);
    final state = logic.states.first;

    // Configure One-Way Mirror, exclude *.tmp
    await logic.updatePairSettings(
      state.config.id,
      'one_way', // syncMode
      'manual',  // schedule
      ['*.tmp'], // excludes
    );

    // 4. Run Sync
    await logic.syncPair(state.config.id);

    // 5. Verify results
    // - a.txt should be updated with source content
    expect(tgtFileA.readAsStringSync(), 'Hello Source A');

    // - c.txt should be copied to target
    final tgtFileC = File(p.join(targetDir.path, 'sub', 'c.txt'));
    expect(tgtFileC.existsSync(), isTrue);
    expect(tgtFileC.readAsStringSync(), 'Sub folder file C');

    // - b.tmp is excluded -> should NOT exist in target
    final tgtFileB = File(p.join(targetDir.path, 'b.tmp'));
    expect(tgtFileB.existsSync(), isFalse);

    // - d.txt should be deleted in target (Mirror mode deletes target-only files)
    expect(tgtFileD.existsSync(), isFalse);

    // 6. Verify sync history was logged in sync_history.json
    final historyFile = File(p.join(tempDir.path, 'logs', 'sync_history.json'));
    expect(historyFile.existsSync(), isTrue);
    final historyContent = historyFile.readAsStringSync();
    final historyList = jsonDecode(historyContent) as List<dynamic>;
    expect(historyList.isNotEmpty, isTrue);

    // There should be a COPY action for a.txt and c.txt, and a DELETE for d.txt
    final actions = historyList.map((e) => e['action']).toList();
    expect(actions.contains('COPY'), isTrue);
    expect(actions.contains('DELETE'), isTrue);
  });

  test('Speed Limit Throttling test', () async {
    // 1. Create a large source file (~1MB)
    final largeFile = File(p.join(sourceDir.path, 'large.bin'));
    final data = List<int>.generate(1024 * 1024, (i) => i % 256);
    await largeFile.writeAsBytes(data);

    // 2. Initialize and run sync with NO speed limit first
    await AppConfig.set('speed_limit', '0'); // Unlimited
    final logic = SyncLogic();
    await logic.initialize();
    await logic.addPair(sourceDir.path, targetDir.path, 'newer_wins');
    
    final state = logic.states.first;
    await logic.updatePairSettings(state.config.id, 'one_way', 'manual', []);

    final stopwatch1 = Stopwatch()..start();
    await logic.syncPair(state.config.id);
    stopwatch1.stop();
    final timeUnlimitedMs = stopwatch1.elapsedMilliseconds;
    // ignore: avoid_print
    print('Unlimited sync took ${timeUnlimitedMs}ms');

    // 3. Clear target and set speed limit to 1 MB/s
    final tgtFile = File(p.join(targetDir.path, 'large.bin'));
    if (tgtFile.existsSync()) tgtFile.deleteSync();

    // Re-initialize manifest to force re-copy
    final manifestFile = File(p.join(tempDir.path, 'manifest_${state.config.id}.json'));
    if (manifestFile.existsSync()) manifestFile.deleteSync();

    await AppConfig.set('speed_limit', '1'); // 1 MB/s limit

    final stopwatch2 = Stopwatch()..start();
    await logic.syncPair(state.config.id);
    stopwatch2.stop();
    final timeLimitedMs = stopwatch2.elapsedMilliseconds;

    // Limited copy should take significantly longer (expecting >= 900ms for 1MB at 1MB/s)
    // while unlimited copy on SSD/in-memory should take < 200ms
    expect(timeLimitedMs, greaterThan(800));
  });

  test('Two-Way Sync Empty Directory Safeguard', () async {
    // 1. Create a source file
    final srcFile = File(p.join(sourceDir.path, 'data.txt'));
    await srcFile.writeAsString('Valuable Source Data');
    final mtime = DateTime.now().subtract(const Duration(minutes: 5));
    await srcFile.setLastModified(mtime);

    // 2. Initialize and run sync so a manifest is written
    final logic = SyncLogic();
    await logic.initialize();
    await logic.addPair(sourceDir.path, targetDir.path, 'newer_wins');
    
    final state = logic.states.first;
    await logic.updatePairSettings(state.config.id, 'two_way', 'manual', []);

    // Initial sync
    await logic.syncPair(state.config.id);

    // Verify target file exists
    final tgtFile = File(p.join(targetDir.path, 'data.txt'));
    expect(tgtFile.existsSync(), isTrue);

    // 3. Simulate wiping the target folder (e.g. fresh machine or manual target wipe)
    // but the manifest files are still kept (as when the app directory was copied).
    await tgtFile.delete();
    expect(targetDir.listSync().isEmpty, isTrue);

    // 4. Run sync again
    await logic.syncPair(state.config.id);

    // 5. Verify results:
    // Without the safeguard, the source file would have been deleted.
    // With the safeguard, the source file MUST NOT be deleted, and should be copied back to target.
    expect(srcFile.existsSync(), isTrue);
    expect(tgtFile.existsSync(), isTrue);
    expect(tgtFile.readAsStringSync(), 'Valuable Source Data');
  });

  test('System files and Office temp files are ignored by scanDirectory', () async {
    // 1. Create mixed files in source, including some system files
    final fileNormal = File(p.join(sourceDir.path, 'regular.txt'));
    await fileNormal.writeAsString('Normal content');

    final fileThumbs = File(p.join(sourceDir.path, 'Thumbs.db'));
    await fileThumbs.writeAsString('dummy db content');

    final fileDesktopIni = File(p.join(sourceDir.path, 'desktop.ini'));
    await fileDesktopIni.writeAsString('dummy desktop ini');

    final fileDsStore = File(p.join(sourceDir.path, '.DS_Store'));
    await fileDsStore.writeAsString('dummy ds_store');

    final fileOfficeTemp = File(p.join(sourceDir.path, r'~$document.docx'));
    await fileOfficeTemp.writeAsString('dummy office temp');

    final fileSubDir = Directory(p.join(sourceDir.path, 'sub'));
    await fileSubDir.create();
    final fileSubOfficeTemp = File(p.join(fileSubDir.path, r'~$another.xlsx'));
    await fileSubOfficeTemp.writeAsString('dummy sub office temp');

    final fileGitConfig = File(p.join(sourceDir.path, '.git', 'config'));
    await fileGitConfig.create(recursive: true);
    await fileGitConfig.writeAsString('git config content');

    final fileNodeModule = File(p.join(sourceDir.path, 'node_modules', 'express', 'index.js'));
    await fileNodeModule.create(recursive: true);
    await fileNodeModule.writeAsString('express js content');

    final filePyCache = File(p.join(sourceDir.path, '__pycache__', 'module.cpython-310.pyc'));
    await filePyCache.create(recursive: true);
    await filePyCache.writeAsString('pyc content');

    final fileIdeaXml = File(p.join(sourceDir.path, '.idea', 'workspace.xml'));
    await fileIdeaXml.create(recursive: true);
    await fileIdeaXml.writeAsString('idea content');

    // 2. Scan directory
    final filesMap = await scanDirectory(sourceDir.path);

    // 3. Verify results
    expect(filesMap.containsKey('regular.txt'), isTrue);
    expect(filesMap.containsKey('Thumbs.db'), isFalse);
    expect(filesMap.containsKey('desktop.ini'), isFalse);
    expect(filesMap.containsKey('.DS_Store'), isFalse);
    expect(filesMap.containsKey(r'~$document.docx'), isFalse);
    expect(filesMap.containsKey(r'sub/~$another.xlsx'), isFalse);
    expect(filesMap.containsKey('.git'), isFalse);
    expect(filesMap.containsKey('.git/config'), isFalse);
    expect(filesMap.containsKey('node_modules'), isFalse);
    expect(filesMap.containsKey('node_modules/express/index.js'), isFalse);
    expect(filesMap.containsKey('__pycache__'), isFalse);
    expect(filesMap.containsKey('__pycache__/module.cpython-310.pyc'), isFalse);
    expect(filesMap.containsKey('.idea'), isFalse);
    expect(filesMap.containsKey('.idea/workspace.xml'), isFalse);
  });

  test('Two-Way Sync Explicit Deletion Safeguard', () async {
    // 1. Setup initial files on both sides to sync them and populate the manifest
    final srcFile = File(p.join(sourceDir.path, 'valuable.txt'));
    await srcFile.writeAsString('Unique Data');
    
    final tgtFile = File(p.join(targetDir.path, 'valuable.txt'));
    await tgtFile.writeAsString('Unique Data');

    final logic = SyncLogic();
    await logic.initialize();
    await logic.addPair(sourceDir.path, targetDir.path, 'newer_wins');
    
    final state = logic.states.first;
    final pairId = state.config.id;

    // Run first sync to establish manifest
    await logic.syncPair(pairId);

    // Verify both files exist
    expect(srcFile.existsSync(), isTrue);
    expect(tgtFile.existsSync(), isTrue);

    // 2. Simulate deletion on target WITHOUT recording it (like sync issue / new machine)
    await tgtFile.delete();
    
    // Add another dummy file to target so target is NOT completely empty (prevent empty folder safeguard)
    final dummyFile = File(p.join(targetDir.path, 'dummy.txt'));
    await dummyFile.writeAsString('dummy');

    // Run sync again
    await logic.syncPair(pairId);

    // VERIFICATION 1:
    // The source file MUST NOT be deleted because there was no recorded delete event!
    // Instead, it must be copied back to target.
    expect(srcFile.existsSync(), isTrue);
    expect(tgtFile.existsSync(), isTrue);
    expect(tgtFile.readAsStringSync(), 'Unique Data');

    // 3. Now simulate an explicit user deletion by deleting the file and recording it
    await tgtFile.delete();
    
    // Record target deletion of 'valuable.txt'
    final exeDir = p.dirname(configFile.path);
    final deletionsFile = File(p.join(exeDir, 'deletions_$pairId.json'));
    
    final json = {
      'deletedOnSource': <String>[],
      'deletedOnTarget': ['valuable.txt']
    };
    await deletionsFile.writeAsString(jsonEncode(json));

    // Run sync again
    await logic.syncPair(pairId);

    // VERIFICATION 2:
    // Now that the deletion was explicitly recorded, the source file MUST be deleted!
    expect(srcFile.existsSync(), isFalse);
    expect(tgtFile.existsSync(), isFalse);
  });

  test('AppConfig JSON Import and Export Validation', () async {
    // 1. Setup clean config state and add one pair
    final testPair = SyncPairConfig(
      id: 'import_export_test_pair',
      sourcePath: 'D:/DummySource',
      targetPath: 'D:/DummyTarget',
      excludes: ['*.log'],
    );
    await AppConfig.addPair(testPair);

    // Verify initial pair exists
    expect(AppConfig.pairs.length, 1);
    expect(AppConfig.pairs.first.id, 'import_export_test_pair');

    // 2. Export configuration
    final exportFile = File(p.join(tempDir.path, 'exported_config.json'));
    await AppConfig.exportConfig(exportFile.path);

    // Verify exported file exists and contains valid JSON
    expect(exportFile.existsSync(), isTrue);
    final content = exportFile.readAsStringSync();
    final json = jsonDecode(content) as Map<String, dynamic>;
    expect(json.containsKey('pairs'), isTrue);
    
    final pairsList = json['pairs'] as List;
    expect(pairsList.length, 1);
    expect(pairsList.first['id'], 'import_export_test_pair');

    // 3. Clear pairs on AppConfig
    await AppConfig.removePair('import_export_test_pair');
    expect(AppConfig.pairs.isEmpty, isTrue);

    // 4. Import the configuration back
    final importSuccess = await AppConfig.importConfig(exportFile.path);
    expect(importSuccess, isTrue);

    // Verify configuration restored
    expect(AppConfig.pairs.length, 1);
    expect(AppConfig.pairs.first.id, 'import_export_test_pair');
    expect(AppConfig.pairs.first.excludes, contains('*.log'));

    // 5. Try importing corrupt/invalid config
    final corruptFile = File(p.join(tempDir.path, 'corrupt.json'));
    await corruptFile.writeAsString('{"pairs": [{"invalid_key": "dummy"}]}');
    final importCorruptSuccess = await AppConfig.importConfig(corruptFile.path);
    expect(importCorruptSuccess, isFalse);
  });

  test('SyncLogic updateAllSchedules changes schedule for all pairs', () async {
    final logic = SyncLogic();
    await logic.initialize();

    // Add some test pairs
    await logic.addPair('D:/S1', 'D:/T1', 'newer_wins');
    await logic.addPair('D:/S2', 'D:/T2', 'newer_wins');

    // Verify initial states
    expect(logic.states.length, 2);

    // Call updateAllSchedules to change everything to 'realtime'
    await logic.updateAllSchedules('realtime');

    // Verify all schedules updated to 'realtime'
    expect(logic.states.every((s) => s.config.schedule == 'realtime'), isTrue);
    expect(logic.states.every((s) => s.config.autoSync == true), isTrue);

    // Clean up pairs using logic.removePair
    final id1 = logic.states[0].config.id;
    final id2 = logic.states[1].config.id;
    await logic.removePair(id1);
    await logic.removePair(id2);
  });
}
