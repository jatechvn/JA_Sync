// lib/main.dart
// Program entry point for JA Sync
// Transparent blur window with Light/Dark/Auto theme + multi-language support

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'modules/constants.dart';
import 'modules/logger_config.dart';
import 'modules/app_config.dart';
import 'modules/i18n.dart';
import 'modules/logic.dart';
import 'modules/ui/styles.dart';
import 'modules/ui/main_window.dart';
import 'package:tray_manager/tray_manager.dart';
import 'modules/build_info.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parse CLI flags for -debug or --debug
  if (args.contains('-debug') || args.contains('--debug') || args.contains('-d')) {
    BuildInfo.isCliDebug = true;
  }

  // Load config from disk (language preference, etc.)
  await AppConfig.initialize();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Configure window
  const windowOptions = WindowOptions(
    size: Size(1100, 700),
    minimumSize: Size(850, 550),
    title: '$appName  v$appVersion',
    titleBarStyle: TitleBarStyle.normal,
  );

  final startMinimized = AppConfig.getBool('start_minimized', defaultValue: false);

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    if (startMinimized) {
      // Hide window initially so it starts in system tray
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
    try {
      await windowManager.setAlignment(Alignment.center);
    } catch (_) {}
  });



  // Initialize logger
  setupLogger();

  // AppConfig has already been initialized at the start of main()

  // Initialize sync logic coordinator
  final syncLogic = SyncLogic();

  // Restore saved language
  final savedLang = AppLanguageExt.fromCode(
      AppConfig.get('language', defaultValue: 'en'));

  runApp(JaSyncApp(
    logic: syncLogic,
    initialLanguage: savedLang,
  ));
}

class JaSyncApp extends StatefulWidget {
  final SyncLogic logic;
  final AppLanguage initialLanguage;

  const JaSyncApp({
    super.key,
    required this.logic,
    required this.initialLanguage,
  });

  @override
  State<JaSyncApp> createState() => _JaSyncAppState();
}

class _JaSyncAppState extends State<JaSyncApp> with TrayListener {
  final ThemeNotifier _themeNotifier = ThemeNotifier();
  late final LanguageNotifier _languageNotifier;

  @override
  void initState() {
    super.initState();
    _languageNotifier = LanguageNotifier(widget.initialLanguage);
    _languageNotifier.addListener(_updateTrayMenu);
    _initTray();
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/images/app_icon.ico'
            : 'assets/images/app_icon.png',
      );
      if (Platform.isWindows) {
        await trayManager.setToolTip('$appName v$appVersion');
      }
      await _updateTrayMenu();
      trayManager.addListener(this);
    } catch (e) {
      // Tray initialization failed/unsupported
    }
  }

  Future<void> _updateTrayMenu() async {
    try {
      final s = _languageNotifier.strings;
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: s.trayShowWindow,
          ),
          MenuItem(
            key: 'exit_app',
            label: s.trayExit,
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      // Tray menu update failed
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    _languageNotifier.removeListener(_updateTrayMenu);
    _themeNotifier.dispose();
    _languageNotifier.dispose();
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    _restoreWindow();
  }

  void _restoreWindow() async {
    try {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.focus();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } catch (_) {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      notifier: _languageNotifier,
      child: ListenableBuilder(
        listenable: Listenable.merge([_themeNotifier, _languageNotifier]),
        builder: (context, _) {
          return MaterialApp(
            title: '$appName  v$appVersion',
            debugShowCheckedModeBanner: false,
            theme: buildThemeData(_themeNotifier.colors),
            themeMode: _themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,
            home: MainWindow(
              logic: widget.logic,
              themeNotifier: _themeNotifier,
              languageNotifier: _languageNotifier,
            ),
          );
        },
      ),
    );
  }
}
