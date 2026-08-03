// lib/modules/ui/dialogs.dart
// Dialog widgets for sync configurations (Add Pair, Remove Pair)

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../app_config.dart';
import '../i18n.dart';
import 'styles.dart';
import '../utils.dart';
import '../logic.dart';
import '../build_info.dart';
import '../../services/settings_service.dart';

/// Dialog to configure and add a new sync pair
class AddSyncPairDialog extends StatefulWidget {
  const AddSyncPairDialog({super.key});

  @override
  State<AddSyncPairDialog> createState() => _AddSyncPairDialogState();
}

class _AddSyncPairDialogState extends State<AddSyncPairDialog> {
  final _sourceController = TextEditingController();
  final _targetController = TextEditingController();
  String _strategy = 'newer_wins';
  String _syncMode = 'two_way';
  String _schedule = 'manual';
  List<String> _excludes = [];
  String? _selectedProfileKey;
  String _errorMessage = '';

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder(TextEditingController controller) async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Directory',
    );
    if (result != null) {
      controller.text = result;
      setState(() {
        _errorMessage = '';
      });
    }
  }

  String _scheduleLabel(String schedule, AppStrings s) {
    switch (schedule) {
      case 'realtime':
        return s.optSchedRealtime;
      case '15m':
        return s.optSched15m;
      case '1h':
        return s.optSched1h;
      case '12h':
        return s.optSched12h;
      case '24h':
        return s.optSched24h;
      default:
        return s.optSchedManual;
    }
  }

  void _applyProfile(String? key) {
    setState(() {
      _selectedProfileKey = key;
      if (key == null) {
        _strategy = 'newer_wins';
        _syncMode = 'two_way';
        _schedule = 'manual';
        _excludes = [];
        return;
      }
      final profile = AppConfig.allProfiles.firstWhere((p) => p.key == key);
      _strategy = profile.conflictStrategy;
      _syncMode = profile.syncMode;
      _schedule = profile.schedule;
      _excludes = profile.excludes;
    });
  }

  void _validateAndSubmit(AppStrings s) {
    final src = _sourceController.text.trim();
    final tgt = _targetController.text.trim();

    if (src.isEmpty || tgt.isEmpty) {
      setState(() => _errorMessage = s.errPathEmpty);
      return;
    }

    final srcDir = Directory(src);
    final tgtDir = Directory(tgt);

    if (!srcDir.existsSync() || !tgtDir.existsSync()) {
      setState(() => _errorMessage = s.errPathNotExist);
      return;
    }

    if (srcDir.path.toLowerCase() == tgtDir.path.toLowerCase()) {
      setState(() => _errorMessage = s.errPathSame);
      return;
    }

    Navigator.pop(context, {
      'source': src,
      'target': tgt,
      'strategy': _strategy,
      'syncMode': _syncMode,
      'schedule': _schedule,
      'excludes': _excludes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.sync_alt, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.btnAddPair),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sourceController,
                    decoration: InputDecoration(
                      labelText: s.labelSource,
                      prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _pickFolder(_sourceController),
                  icon: Icon(Icons.folder_open, color: c.linkAccent),
                  tooltip: s.btnBrowse,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Target Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetController,
                    decoration: InputDecoration(
                      labelText: s.labelTarget,
                      prefixIcon: const Icon(
                        Icons.folder_shared_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _pickFolder(_targetController),
                  icon: Icon(Icons.folder_open, color: c.linkAccent),
                  tooltip: s.btnBrowse,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Profile Selector (optional)
            Text(
              s.labelApplyProfile,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.bgTertiary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.borderDefault),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedProfileKey,
                  dropdownColor: c.bgSecondary,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  isExpanded: true,
                  hint: Text(s.optNoProfile),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(s.optNoProfile),
                    ),
                    for (final profile in AppConfig.allProfiles)
                      DropdownMenuItem<String?>(
                        value: profile.key,
                        child: Text(profile.displayName(s)),
                      ),
                  ],
                  onChanged: _applyProfile,
                ),
              ),
            ),
            if (_selectedProfileKey != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_syncMode == 'one_way' ? s.optOneWay : s.optTwoWay} · ${_scheduleLabel(_schedule, s)}'
                '${_excludes.isNotEmpty ? ' · ${_excludes.length} ${s.labelExcludes}' : ''}',
                style: TextStyle(color: c.textMuted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),

            // Strategy Selector
            Text(
              s.labelConflictStrategy,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.bgTertiary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.borderDefault),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _strategy,
                  dropdownColor: c.bgSecondary,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'newer_wins',
                      child: Text(s.strategyNewerWins),
                    ),
                    DropdownMenuItem(
                      value: 'source_wins',
                      child: Text(s.strategySourceWins),
                    ),
                    DropdownMenuItem(
                      value: 'target_wins',
                      child: Text(s.strategyTargetWins),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _strategy = val);
                    }
                  },
                ),
              ),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: c.statusRemoved,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnCancel),
        ),
        ElevatedButton(
          onPressed: () => _validateAndSubmit(s),
          child: Text(s.btnAdd),
        ),
      ],
    );
  }
}

/// Dialog to confirm removal of a sync pair
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: c.statusRemoved, size: 24),
          const SizedBox(width: 10),
          Text(s.confirmDeleteTitle),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Text(
          s.confirmDeleteDesc,
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.btnCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.statusRemoved,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.btnDelete),
        ),
      ],
    );
  }
}

/// Dialog to ask the user what to do on close click
class CloseActionDialog extends StatefulWidget {
  const CloseActionDialog({super.key});

  @override
  State<CloseActionDialog> createState() => _CloseActionDialogState();
}

class _CloseActionDialogState extends State<CloseActionDialog> {
  String _selectedAction = 'minimize'; // 'minimize' or 'exit'
  bool _rememberChoice = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.exit_to_app, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.dlgCloseTitle),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.dlgCloseDesc,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            RadioGroup<String>(
              groupValue: _selectedAction,
              onChanged: (val) {
                if (val != null) setState(() => _selectedAction = val);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(
                      s.optMinimizeToTray,
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                    ),
                    value: 'minimize',
                    activeColor: c.linkAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: Text(
                      s.optExitApp,
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                    ),
                    value: 'exit',
                    activeColor: c.linkAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Checkbox Remember
            CheckboxListTile(
              title: Text(
                s.labelRememberChoice,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: _rememberChoice,
              activeColor: c.linkAccent,
              contentPadding: EdgeInsets.zero,
              dense: true,
              onChanged: (val) {
                if (val != null) setState(() => _rememberChoice = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(s.btnCancel),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_rememberChoice) {
              await AppConfig.set('close_action', _selectedAction);
            }
            if (context.mounted) {
              Navigator.pop(context, _selectedAction);
            }
          },
          child: Text(s.btnConfirm),
        ),
      ],
    );
  }
}

/// Dialog to show and manage settings
class SettingsDialog extends StatefulWidget {
  final ThemeNotifier themeNotifier;
  final LanguageNotifier languageNotifier;

  const SettingsDialog({
    super.key,
    required this.themeNotifier,
    required this.languageNotifier,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _startWithWindows = false;
  bool _startMinimized = false;
  String _closeAction = 'ask';
  late AppThemeMode _themeMode;
  late AppLanguage _language;
  bool _loadingStartup = true;
  int _speedLimit = 0;

  double _bgBlur = 10.0;
  double _bgOpacity = 0.6;
  double _dialogBlur = 2.0;
  double _dialogOpacity = 0.8;
  String _licenseAuthor = 'John Alaa';
  int _maxDepth = 3;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeNotifier.mode;
    _language = widget.languageNotifier.current;
    _closeAction = AppConfig.get('close_action', defaultValue: 'ask');
    _speedLimit =
        int.tryParse(AppConfig.get('speed_limit', defaultValue: '0')) ?? 0;
    _startMinimized = AppConfig.getBool('start_minimized', defaultValue: false);
    _loadStoredSettings();
    _loadStartupStatus();
  }

  void _loadStoredSettings() {
    final settings = SettingsService.loadSettings();
    setState(() {
      _bgBlur = (settings['bg_blur'] as num?)?.toDouble() ?? 10.0;
      _bgOpacity = (settings['bg_opacity'] as num?)?.toDouble() ?? 0.6;
      _dialogBlur = (settings['dialog_blur'] as num?)?.toDouble() ?? 2.0;
      _dialogOpacity = (settings['dialog_opacity'] as num?)?.toDouble() ?? 0.8;
      _licenseAuthor = settings['license_author']?.toString() ?? 'John Alaa';
      _maxDepth = (settings['max_depth'] as num?)?.toInt() ?? 3;
    });
  }

  Future<void> _loadStartupStatus() async {
    final enabled = await isStartWithWindowsEnabled();
    setState(() {
      _startWithWindows = enabled;
      _loadingStartup = false;
    });
  }

  Future<void> _toggleStartup(bool val) async {
    setState(() => _loadingStartup = true);
    final success = await setStartWithWindows(val);
    if (success) {
      await AppConfig.setBool('start_with_windows', val);
      setState(() {
        _startWithWindows = val;
      });
    }
    setState(() => _loadingStartup = false);
  }

  void _resetToDefaults() {
    setState(() {
      _bgBlur = 10.0;
      _bgOpacity = 0.6;
      _dialogBlur = 2.0;
      _dialogOpacity = 0.8;
      _licenseAuthor = 'John Alaa';
      _maxDepth = 3;
      _speedLimit = 0;
      _closeAction = 'ask';
      _startMinimized = false;
    });
  }

  Future<void> _saveSettings() async {
    await SettingsService.saveSettings({
      'bg_blur': _bgBlur,
      'bg_opacity': _bgOpacity,
      'dialog_blur': _dialogBlur,
      'dialog_opacity': _dialogOpacity,
      'license_author': _licenseAuthor,
      'max_depth': _maxDepth,
      'speed_limit': _speedLimit,
      'close_action': _closeAction,
      'start_with_windows': _startWithWindows,
      'start_minimized': _startMinimized,
    });
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: c.linkAccent, size: 24),
                const SizedBox(width: 10),
                Text(s.settingsTitle),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              labelColor: c.linkAccent,
              unselectedLabelColor: c.textMuted,
              indicatorColor: c.linkAccent,
              isScrollable: false,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.tune_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        s.lang == AppLanguage.vi
                            ? 'Cài đặt'
                            : s.lang == AppLanguage.zh
                            ? '设置'
                            : 'Advanced',
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        s.lang == AppLanguage.vi
                            ? 'Hướng dẫn'
                            : s.lang == AppLanguage.zh
                            ? '指南'
                            : 'User Guide',
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        s.lang == AppLanguage.vi
                            ? 'Giới thiệu'
                            : s.lang == AppLanguage.zh
                            ? '关于'
                            : 'About',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 480,
          child: TabBarView(
            children: [
              // TAB 1: Advanced Settings
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      s.secGeneral,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.linkAccent,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Start with Windows
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.labelStartWithWindows,
                        style: TextStyle(color: c.textPrimary, fontSize: 13),
                      ),
                      trailing: _loadingStartup
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: _startWithWindows,
                              activeTrackColor: c.linkAccent.withValues(
                                alpha: 0.5,
                              ),
                              activeThumbColor: c.linkAccent,
                              onChanged: _toggleStartup,
                            ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.labelStartMinimized,
                        style: TextStyle(color: c.textPrimary, fontSize: 13),
                      ),
                      trailing: Switch(
                        value: _startMinimized,
                        activeTrackColor: c.linkAccent.withValues(alpha: 0.5),
                        activeThumbColor: c.linkAccent,
                        onChanged: (val) async {
                          await AppConfig.setBool('start_minimized', val);
                          setState(() {
                            _startMinimized = val;
                          });
                        },
                      ),
                    ),

                    // Close Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.labelCloseAction,
                          style: TextStyle(color: c.textPrimary, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.bgTertiary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _closeAction,
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                              ),
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'ask',
                                  child: Text(s.optCloseAsk),
                                ),
                                DropdownMenuItem(
                                  value: 'minimize',
                                  child: Text(s.optCloseMinimize),
                                ),
                                DropdownMenuItem(
                                  value: 'exit',
                                  child: Text(s.optCloseExit),
                                ),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  await AppConfig.set('close_action', val);
                                  setState(() => _closeAction = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Speed Limit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.labelSpeedLimit,
                          style: TextStyle(color: c.textPrimary, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.bgTertiary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _speedLimit,
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                              ),
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(
                                    s.lang == AppLanguage.vi
                                        ? 'Không giới hạn'
                                        : s.lang == AppLanguage.zh
                                        ? '无限制'
                                        : 'Unlimited',
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: 1,
                                  child: Text('1 MB/s'),
                                ),
                                const DropdownMenuItem(
                                  value: 5,
                                  child: Text('5 MB/s'),
                                ),
                                const DropdownMenuItem(
                                  value: 10,
                                  child: Text('10 MB/s'),
                                ),
                                const DropdownMenuItem(
                                  value: 50,
                                  child: Text('50 MB/s'),
                                ),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  await AppConfig.set(
                                    'speed_limit',
                                    val.toString(),
                                  );
                                  setState(() => _speedLimit = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),

                    // Interface Section
                    Text(
                      s.secInterface,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.linkAccent,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Theme Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.labelTheme,
                          style: TextStyle(color: c.textPrimary, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.bgTertiary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AppThemeMode>(
                              value: _themeMode,
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                              ),
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: AppThemeMode.dark,
                                  child: Text(s.themeDark),
                                ),
                                DropdownMenuItem(
                                  value: AppThemeMode.light,
                                  child: Text(s.themeLight),
                                ),
                                DropdownMenuItem(
                                  value: AppThemeMode.auto,
                                  child: Text(s.themeAuto),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  widget.themeNotifier.setMode(
                                    val,
                                    MediaQuery.of(context).platformBrightness,
                                  );
                                  setState(() => _themeMode = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Language Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.labelLanguage,
                          style: TextStyle(color: c.textPrimary, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.bgTertiary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AppLanguage>(
                              value: _language,
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                              ),
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: AppLanguage.en,
                                  child: Text(AppLanguage.en.fullLabel),
                                ),
                                DropdownMenuItem(
                                  value: AppLanguage.vi,
                                  child: Text(AppLanguage.vi.fullLabel),
                                ),
                                DropdownMenuItem(
                                  value: AppLanguage.zh,
                                  child: Text(AppLanguage.zh.fullLabel),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  widget.languageNotifier.changeLanguage(val);
                                  setState(() => _language = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),

                    // Glassmorphism Customization ExpansionTile
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        listTileTheme: const ListTileThemeData(dense: true),
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          s.lang == AppLanguage.vi
                              ? 'Tùy chỉnh Glassmorphism (Blur & Opacity)'
                              : s.lang == AppLanguage.zh
                              ? 'Glassmorphism 自定义 (模糊 & 不透明度)'
                              : 'Glassmorphism Customization (Blur & Opacity)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: c.linkAccent,
                          ),
                        ),
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Background Blur (Sigma: ${_bgBlur.toStringAsFixed(1)})',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _bgBlur,
                                min: 0.0,
                                max: 30.0,
                                activeColor: c.linkAccent,
                                onChanged: (val) =>
                                    setState(() => _bgBlur = val),
                              ),
                              Text(
                                'App Background Opacity (${(_bgOpacity * 100).round()}%)',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _bgOpacity,
                                min: 0.1,
                                max: 1.0,
                                activeColor: c.linkAccent,
                                onChanged: (val) =>
                                    setState(() => _bgOpacity = val),
                              ),
                              Text(
                                'Popup Dialog Blur (Sigma: ${_dialogBlur.toStringAsFixed(1)})',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _dialogBlur,
                                min: 0.0,
                                max: 30.0,
                                activeColor: c.linkAccent,
                                onChanged: (val) =>
                                    setState(() => _dialogBlur = val),
                              ),
                              Text(
                                'Popup Dialog Opacity (${(_dialogOpacity * 100).round()}%)',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _dialogOpacity,
                                min: 0.1,
                                max: 1.0,
                                activeColor: c.linkAccent,
                                onChanged: (val) =>
                                    setState(() => _dialogOpacity = val),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),

                    // Configuration Import / Export Section
                    Text(
                      s.lang == AppLanguage.vi
                          ? 'Nhập & Xuất Cấu Hình JSON'
                          : s.lang == AppLanguage.zh
                          ? '导入/导出 JSON 配置'
                          : 'Import & Export JSON Config',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.linkAccent,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final destPath = await FilePicker.saveFile(
                                dialogTitle: s.lang == AppLanguage.vi
                                    ? 'Chọn nơi lưu cấu hình'
                                    : s.lang == AppLanguage.zh
                                    ? '选择保存配置的位置'
                                    : 'Select location to save configuration',
                                fileName: 'ja_sync_config.json',
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                              );
                              if (destPath != null) {
                                await AppConfig.exportConfig(destPath);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        s.lang == AppLanguage.vi
                                            ? 'Xuất cấu hình thành công!'
                                            : s.lang == AppLanguage.zh
                                            ? '成功导出配置！'
                                            : 'Configuration exported successfully!',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.upload_rounded, size: 16),
                            label: Text(
                              s.lang == AppLanguage.vi
                                  ? 'Xuất'
                                  : s.lang == AppLanguage.zh
                                  ? '导出'
                                  : 'Export',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(
                                dialogTitle: s.lang == AppLanguage.vi
                                    ? 'Chọn tệp cấu hình JSON'
                                    : s.lang == AppLanguage.zh
                                    ? '选择 JSON 配置文件'
                                    : 'Select JSON configuration file',
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                              );
                              if (result != null &&
                                  result.files.single.path != null) {
                                final success = await AppConfig.importConfig(
                                  result.files.single.path!,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? (s.lang == AppLanguage.vi
                                                  ? 'Nhập cấu hình thành công! Hãy khởi động lại ứng dụng nếu cần.'
                                                  : s.lang == AppLanguage.zh
                                                  ? '配置导入成功！如果需要，请重启应用。'
                                                  : 'Configuration imported successfully! Restart the app if needed.')
                                            : (s.lang == AppLanguage.vi
                                                  ? 'Nhập cấu hình thất bại! Định dạng file không hợp lệ.'
                                                  : s.lang == AppLanguage.zh
                                                  ? '导入配置失败！文件格式无效。'
                                                  : 'Failed to import configuration! Invalid file format.'),
                                      ),
                                      backgroundColor: success
                                          ? c.statusActive
                                          : c.statusRemoved,
                                    ),
                                  );
                                  if (success) {
                                    Navigator.pop(context);
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              s.lang == AppLanguage.vi
                                  ? 'Nhập'
                                  : s.lang == AppLanguage.zh
                                  ? '导入'
                                  : 'Import',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // TAB 2: User Guide
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      s.lang == AppLanguage.vi
                          ? 'Hướng dẫn & Mẹo sử dụng'
                          : s.lang == AppLanguage.zh
                          ? '使用指南与技巧'
                          : 'Guide & Tips',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.linkAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.guideContent,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.linkAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.linkAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            color: c.linkAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.lang == AppLanguage.vi
                                  ? 'Mẹo: Bạn có thể cài đặt tốc độ giới hạn băng thông trong tab Cài đặt để không ảnh hưởng tới mạng cục bộ.'
                                  : s.lang == AppLanguage.zh
                                  ? '提示：您可以在设置选项卡中设置带宽限制，以免影响局域网。'
                                  : 'Tip: You can set a bandwidth limit in the Settings tab to avoid impacting your local network performance.',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // TAB 3: About Application
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            color: c.linkAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'JA Sync Manager',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            'Version v${BuildInfo.version}',
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                          ),
                          if (BuildInfo.isDebug) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'DEBUG • ${BuildInfo.debugTimestamp}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      s.aboutContent,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.bgTertiary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.borderDefault),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Build Mode:',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                BuildInfo.modeName,
                                style: TextStyle(
                                  color: BuildInfo.isDebug
                                      ? Colors.amber
                                      : c.linkAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (BuildInfo.isDebug) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Debug Timestamp:',
                                  style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  BuildInfo.debugTimestamp,
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tech Stack:',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Flutter 3.x / Dart 3.x',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Developer / Author:',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _licenseAuthor,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Managed By:',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'JA Auto Git',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: _resetToDefaults,
            child: Text(
              s.lang == AppLanguage.vi
                  ? 'Khôi phục mặc định'
                  : s.lang == AppLanguage.zh
                  ? '恢复默认'
                  : 'Reset Defaults',
            ),
          ),
          ElevatedButton(
            onPressed: _saveSettings,
            child: Text(
              s.lang == AppLanguage.vi
                  ? 'Lưu cài đặt'
                  : s.lang == AppLanguage.zh
                  ? '保存设置'
                  : 'Save Settings',
            ),
          ),
        ],
      ),
    );
  }
}

class AboutGuideDialog extends StatelessWidget {
  const AboutGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.labelAboutGuide),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JA Sync Manager',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.aboutContent,
                style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                s.lang == AppLanguage.vi
                    ? 'Hướng dẫn & Mẹo sử dụng'
                    : s.lang == AppLanguage.zh
                    ? '使用指南与技巧'
                    : 'Guide & Tips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c.linkAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.guideContent,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.linkAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: c.linkAccent.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      color: c.linkAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.lang == AppLanguage.vi
                            ? 'Mẹo: Bạn có thể cài đặt tốc độ giới hạn băng thông trong hộp thoại Cài đặt (Settings) để không ảnh hưởng tới mạng cục bộ.'
                            : s.lang == AppLanguage.zh
                            ? '提示：您可以在“设置”对话框中设置带宽限制，以免影响局域网。'
                            : 'Tip: You can set a bandwidth limit in the Settings dialog to avoid impacting your local network performance.',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnConfirm),
        ),
      ],
    );
  }
}

/// Dialog to configure custom settings for a specific sync pair
class PairSettingsDialog extends StatefulWidget {
  final SyncPairConfig config;
  final SyncLogic logic;

  const PairSettingsDialog({
    super.key,
    required this.config,
    required this.logic,
  });

  @override
  State<PairSettingsDialog> createState() => _PairSettingsDialogState();
}

class _PairSettingsDialogState extends State<PairSettingsDialog> {
  late String _syncMode;
  late String _schedule;
  final _excludesController = TextEditingController();

  bool _isNetworkPath(String path) {
    return path.startsWith(r'\\') || path.startsWith('//');
  }

  @override
  void initState() {
    super.initState();
    _syncMode = widget.config.syncMode;
    _schedule = widget.config.schedule;
    _excludesController.text = widget.config.excludes.join(', ');
  }

  @override
  void dispose() {
    _excludesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsedExcludes = _excludesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await widget.logic.updatePairSettings(
      widget.config.id,
      _syncMode,
      _schedule,
      parsedExcludes,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _saveAsProfile() async {
    final s = LanguageProvider.of(context);
    final c = context.appColors;
    final nameController = TextEditingController();
    String? error;

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(s.dlgSaveProfileTitle),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: s.labelProfileName),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(color: c.statusRemoved, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(s.btnCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = nameController.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => error = s.errProfileNameEmpty);
                  return;
                }
                final exists = AppConfig.allProfiles.any(
                  (p) => p.key.toLowerCase() == trimmed.toLowerCase(),
                );
                if (exists) {
                  setDialogState(() => error = s.errProfileNameExists);
                  return;
                }
                Navigator.pop(dialogContext, trimmed);
              },
              child: Text(s.btnSave),
            ),
          ],
        ),
      ),
    );

    if (name == null) return;

    final parsedExcludes = _excludesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await AppConfig.saveCustomProfile(
      SyncProfile(
        key: name,
        syncMode: _syncMode,
        conflictStrategy: widget.config.conflictStrategy,
        schedule: _schedule,
        excludes: parsedExcludes,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.msgProfileSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune_rounded, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.btnPairSettings),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sync Mode Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.labelSyncMode,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.bgTertiary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _syncMode,
                        dropdownColor: c.bgSecondary,
                        style: TextStyle(color: c.textPrimary, fontSize: 13),
                        isDense: true,
                        items: [
                          DropdownMenuItem(
                            value: 'two_way',
                            child: Text(s.optTwoWay),
                          ),
                          DropdownMenuItem(
                            value: 'one_way',
                            child: Text(s.optOneWay),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _syncMode = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Schedule Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.labelSchedule,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.bgTertiary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _schedule,
                        dropdownColor: c.bgSecondary,
                        style: TextStyle(color: c.textPrimary, fontSize: 13),
                        isDense: true,
                        items: [
                          DropdownMenuItem(
                            value: 'manual',
                            child: Text(s.optSchedManual),
                          ),
                          DropdownMenuItem(
                            value: 'realtime',
                            child: Text(s.optSchedRealtime),
                          ),
                          DropdownMenuItem(
                            value: '15m',
                            child: Text(s.optSched15m),
                          ),
                          DropdownMenuItem(
                            value: '1h',
                            child: Text(s.optSched1h),
                          ),
                          DropdownMenuItem(
                            value: '12h',
                            child: Text(s.optSched12h),
                          ),
                          DropdownMenuItem(
                            value: '24h',
                            child: Text(s.optSched24h),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _schedule = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (_schedule == 'realtime' &&
                  (_isNetworkPath(widget.config.sourcePath) ||
                      _isNetworkPath(widget.config.targetPath))) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.statusRemoved.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: c.statusRemoved.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: c.statusRemoved,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.warnNetworkPathRealtime,
                          style: TextStyle(
                            color: c.statusRemoved,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Excludes list Input
              Text(
                s.labelExcludes,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _excludesController,
                decoration: const InputDecoration(
                  hintText: '*.tmp, node_modules, .git',
                ),
                style: TextStyle(color: c.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saveAsProfile,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: Text(s.btnSaveAsProfile),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnCancel),
        ),
        ElevatedButton(onPressed: _save, child: Text(s.btnSave)),
      ],
    );
  }
}

/// Dialog showing a dry-run preview of what a sync would do, without
/// touching any file, manifest, or deletion record.
class PreviewSyncDialog extends StatefulWidget {
  final SyncLogic logic;
  final String pairId;

  const PreviewSyncDialog({
    super.key,
    required this.logic,
    required this.pairId,
  });

  @override
  State<PreviewSyncDialog> createState() => _PreviewSyncDialogState();
}

class _PreviewSyncDialogState extends State<PreviewSyncDialog> {
  bool _isLoading = true;
  bool _hasError = false;
  List<SyncAction> _actions = [];

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final actions = await widget.logic.previewSync(widget.pairId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = actions == null;
      _actions = actions ?? [];
    });
  }

  String _actionLabel(SyncAction action, AppStrings s) {
    switch (action.type) {
      case 'copy_src_to_tgt':
        return s.previewActionCopyToTarget;
      case 'copy_tgt_to_src':
        return s.previewActionCopyToSource;
      case 'delete_tgt':
        return s.previewActionDeleteFromTarget;
      case 'delete_src':
        return s.previewActionDeleteFromSource;
      case 'create_dir_src':
      case 'create_dir_tgt':
        return s.previewActionCreateFolder;
      default:
        return action.type;
    }
  }

  Color _actionColor(String type, AppColors c) {
    if (type.startsWith('copy')) return c.linkAccent;
    if (type.startsWith('delete')) return c.statusRemoved;
    return c.statusChanged;
  }

  IconData _actionIcon(String type) {
    if (type.startsWith('copy')) return Icons.file_copy_outlined;
    if (type.startsWith('delete')) return Icons.delete_outline;
    return Icons.create_new_folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    final copyCount = _actions.where((a) => a.type.startsWith('copy')).length;
    final deleteCount =
        _actions.where((a) => a.type.startsWith('delete')).length;
    final dirCount =
        _actions.where((a) => a.type.startsWith('create_dir')).length;

    Widget body;
    if (_isLoading) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.linkAccent),
            const SizedBox(height: 12),
            Text(
              s.previewLoading,
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_hasError) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.statusRemoved),
            const SizedBox(height: 12),
            Text(
              s.previewErrorPaths,
              style: TextStyle(color: c.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_actions.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: c.statusActive),
            const SizedBox(height: 12),
            Text(
              s.previewNoChanges,
              style: TextStyle(color: c.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.linkAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              s.previewSummary(copyCount, deleteCount, dirCount),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _actions.length,
              itemBuilder: (context, index) {
                final action = _actions[index];
                final color = _actionColor(action.type, c);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  color: c.bgTertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: c.borderDefault),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(_actionIcon(action.type), color: color, size: 20),
                    title: Text(
                      action.relativePath,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      action.size > 0
                          ? '${_actionLabel(action, s)} · ${formatFileSize(action.size)}'
                          : _actionLabel(action, s),
                      style: TextStyle(color: c.textMuted, fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.visibility_outlined, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.previewDialogTitle),
        ],
      ),
      content: SizedBox(width: 520, height: 420, child: body),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnClose),
        ),
      ],
    );
  }
}

/// Dialog to view built-in profiles and manage (delete) custom ones.
class ProfilesDialog extends StatefulWidget {
  const ProfilesDialog({super.key});

  @override
  State<ProfilesDialog> createState() => _ProfilesDialogState();
}

class _ProfilesDialogState extends State<ProfilesDialog> {
  Future<void> _confirmDelete(SyncProfile profile, AppStrings s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.confirmDeleteTitle),
        content: Text(s.confirmDeleteProfileDesc),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.btnCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appColors.statusRemoved,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.btnDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppConfig.deleteCustomProfile(profile.key);
      if (mounted) setState(() {});
    }
  }

  Widget _profileTile(SyncProfile profile, AppStrings s, AppColors c) {
    final desc = profile.displayDescription(s);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: c.bgTertiary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.borderDefault),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          profile.isBuiltIn ? Icons.bookmark : Icons.bookmark_outline,
          color: c.linkAccent,
          size: 20,
        ),
        title: Text(
          profile.displayName(s),
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          desc.isNotEmpty
              ? desc
              : '${profile.syncMode == 'one_way' ? s.optOneWay : s.optTwoWay} · ${profile.schedule}',
          style: TextStyle(color: c.textMuted, fontSize: 11),
        ),
        trailing: profile.isBuiltIn
            ? null
            : IconButton(
                icon: Icon(Icons.delete_outline, color: c.statusRemoved),
                tooltip: s.btnDelete,
                onPressed: () => _confirmDelete(profile, s),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bookmarks_outlined, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.profilesDialogTitle),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.labelBuiltInProfiles,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (final profile in AppConfig.builtInProfiles)
                _profileTile(profile, s, c),
              const SizedBox(height: 12),
              Text(
                s.labelCustomProfiles,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (AppConfig.customProfiles.isEmpty)
                Text(
                  s.emptyCustomProfiles,
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                )
              else
                for (final profile in AppConfig.customProfiles)
                  _profileTile(profile, s, c),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnClose),
        ),
      ],
    );
  }
}

/// Dialog to show the structured JSON sync history log
class HistoryDialog extends StatefulWidget {
  const HistoryDialog({super.key});

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final historyFile = File(p.join(exeDir, 'logs', 'sync_history.json'));
      if (await historyFile.exists()) {
        final content = await historyFile.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        setState(() {
          _history = list;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() {
      _history = [];
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final historyFile = File(p.join(exeDir, 'logs', 'sync_history.json'));
      if (await historyFile.exists()) {
        await historyFile.delete();
      }
    } catch (_) {}
    setState(() {
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.history, color: c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(s.historyTitle),
          const Spacer(),
          if (_history.isNotEmpty)
            TextButton.icon(
              onPressed: _clearHistory,
              icon: Icon(Icons.delete_sweep, color: c.statusRemoved, size: 18),
              label: Text(
                s.btnDelete,
                style: TextStyle(color: c.statusRemoved, fontSize: 12),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 400,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.linkAccent))
            : _history.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: c.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.historyEmpty,
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index] as Map<String, dynamic>;
                  final action = item['action'] ?? '';
                  final isSuccess = item['status'] == 'SUCCESS';
                  final time = item['time'] ?? '';
                  final file = item['file'] ?? '';
                  final details = item['details'] ?? '';

                  IconData icon;
                  Color iconColor;
                  if (action == 'COPY') {
                    icon = Icons.file_copy_outlined;
                    iconColor = isSuccess ? c.linkAccent : c.statusRemoved;
                  } else if (action == 'DELETE') {
                    icon = Icons.delete_outline;
                    iconColor = isSuccess ? c.targetAccent : c.statusRemoved;
                  } else {
                    icon = Icons.warning_amber_rounded;
                    iconColor = c.statusRemoved;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: c.bgTertiary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: c.borderDefault),
                    ),
                    child: ListTile(
                      leading: Icon(icon, color: iconColor, size: 20),
                      dense: true,
                      title: Text(
                        file.isNotEmpty ? file : details,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        file.isNotEmpty ? '$time | $details' : time,
                        style: TextStyle(color: c.textMuted, fontSize: 10),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isSuccess ? c.statusActive : c.statusRemoved)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSuccess ? 'OK' : 'ERR',
                          style: TextStyle(
                            color: isSuccess ? c.statusActive : c.statusRemoved,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnConfirm),
        ),
      ],
    );
  }
}
