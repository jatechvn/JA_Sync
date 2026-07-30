// lib/modules/ui/styles.dart
// Theme configuration and styling for JA Sync
// Supports Light/Dark/Auto themes with transparent blur backgrounds

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'styles_win10.dart';
import 'styles_win11.dart';

/// Theme mode enum
enum AppThemeMode { light, dark, auto }

bool _isWindows10() {
  try {
    if (Platform.isWindows) {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'Build (\d+)').firstMatch(version);
      if (match != null) {
        final buildNum = int.tryParse(match.group(1) ?? '');
        if (buildNum != null && buildNum < 22000) {
          return true;
        }
      } else if (version.contains('Windows 10')) {
        return true;
      }
    }
  } catch (_) {}
  return false;
}

/// Dynamic theme colors that change based on Light/Dark mode
class AppColors {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color bgCard;
  final Color bgHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderDefault;
  final Color borderHighlight;
  final Color linkAccent;
  final Color targetAccent;
  final Color statusActive;
  final Color statusRemoved;
  final Color statusChanged;
  final Brightness brightness;

  const AppColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.bgCard,
    required this.bgHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderDefault,
    required this.borderHighlight,
    required this.linkAccent,
    required this.targetAccent,
    required this.statusActive,
    required this.statusRemoved,
    required this.statusChanged,
    required this.brightness,
  });

  // Dark theme colors (transparent for blur)
  static final dark = AppColors(
    bgPrimary: _isWindows10() ? AppColorsWin10.darkBgPrimary : AppColorsWin11.darkBgPrimary,
    bgSecondary: _isWindows10() ? AppColorsWin10.darkBgSecondary : AppColorsWin11.darkBgSecondary,
    bgTertiary: _isWindows10() ? AppColorsWin10.darkBgTertiary : AppColorsWin11.darkBgTertiary,
    bgCard: _isWindows10() ? AppColorsWin10.darkBgCard : AppColorsWin11.darkBgCard,
    bgHover: const Color(0x1F38BDF8), // soft sky blue highlight
    textPrimary: const Color(0xFFF8FAFC), // slate 50, crisp white
    textSecondary: const Color(0xFFE2E8F0), // slate 200, highly visible grey
    textMuted: const Color(0xFF94A3B8), // slate 400
    borderDefault: const Color(0x2B94A3B8), // slate 400 with 17% opacity
    borderHighlight: const Color(0xFF38BDF8), // sky 400
    linkAccent: const Color(0xFF38BDF8),
    targetAccent: const Color(0xFF34D399), // emerald 400
    statusActive: const Color(0xFF34D399),
    statusRemoved: const Color(0xFFF87171),
    statusChanged: const Color(0xFFFBBF24),
    brightness: Brightness.dark,
  );

  // Light theme colors (transparent for blur)
  static final light = AppColors(
    bgPrimary: _isWindows10() ? AppColorsWin10.lightBgPrimary : AppColorsWin11.lightBgPrimary,
    bgSecondary: _isWindows10() ? AppColorsWin10.lightBgSecondary : AppColorsWin11.lightBgSecondary,
    bgTertiary: _isWindows10() ? AppColorsWin10.lightBgTertiary : AppColorsWin11.lightBgTertiary,
    bgCard: _isWindows10() ? AppColorsWin10.lightBgCard : AppColorsWin11.lightBgCard,
    bgHover: const Color(0x190284C7), // soft sky blue highlight
    textPrimary: const Color(0xFF0F172A), // slate 900
    textSecondary: const Color(0xFF334155), // slate 700, highly visible dark grey
    textMuted: const Color(0xFF64748B), // slate 500
    borderDefault: const Color(0x2664748B), // slate 500 with 15% opacity
    borderHighlight: const Color(0xFF0284C7), // sky 600
    linkAccent: const Color(0xFF0284C7),
    targetAccent: const Color(0xFF0F766E), // teal 700
    statusActive: const Color(0xFF16A34A),
    statusRemoved: const Color(0xFFDC2626),
    statusChanged: const Color(0xFFD97706),
    brightness: Brightness.light,
  );

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IDLE':
        return textMuted;
      case 'SCANNING':
        return statusChanged;
      case 'SYNCING':
        return linkAccent;
      case 'COMPLETED':
        return statusActive;
      case 'ERROR':
        return statusRemoved;
      default:
        return textMuted;
    }
  }
}

/// Extension on BuildContext to easily access custom AppColors
extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}

/// Theme notifier for global state
class ThemeNotifier extends ChangeNotifier {
  static const _channel = MethodChannel('ja_route/theme');

  AppThemeMode _mode = AppThemeMode.dark;
  late AppColors _colors;

  ThemeNotifier() {
    _colors = AppColors.dark;
    _applyNativeTheme();
  }

  AppThemeMode get mode => _mode;
  AppColors get colors => _colors;
  bool get isDark => _colors.brightness == Brightness.dark;

  void setMode(AppThemeMode mode, Brightness platformBrightness) {
    _mode = mode;
    switch (mode) {
      case AppThemeMode.dark:
        _colors = AppColors.dark;
        break;
      case AppThemeMode.light:
        _colors = AppColors.light;
        break;
      case AppThemeMode.auto:
        _colors = platformBrightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        break;
    }
    _applyNativeTheme();
    notifyListeners();
  }

  void toggle(Brightness platformBrightness) {
    switch (_mode) {
      case AppThemeMode.dark:
        setMode(AppThemeMode.light, platformBrightness);
        break;
      case AppThemeMode.light:
        setMode(AppThemeMode.auto, platformBrightness);
        break;
      case AppThemeMode.auto:
        setMode(AppThemeMode.dark, platformBrightness);
        break;
    }
  }

  Future<void> _applyNativeTheme() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('updateTheme', {'isDark': isDark});
    } catch (e) {
      debugPrint('Failed to apply native theme: $e');
    }
  }

  IconData get modeIcon {
    switch (_mode) {
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.auto:
        return Icons.brightness_auto;
    }
  }

  String get modeLabel {
    switch (_mode) {
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.auto:
        return 'Auto';
    }
  }
}

/// Build ThemeData from AppColors
ThemeData buildThemeData(AppColors c) {
  return ThemeData(
    brightness: c.brightness,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: c.linkAccent,
    colorScheme: ColorScheme(
      brightness: c.brightness,
      primary: c.linkAccent,
      secondary: c.statusActive,
      surface: c.bgSecondary,
      error: c.statusRemoved,
      onPrimary: c.brightness == Brightness.dark
          ? const Color(0xFF0D1117)
          : Colors.white,
      onSecondary: c.brightness == Brightness.dark
          ? const Color(0xFF0D1117)
          : Colors.white,
      onSurface: c.textPrimary,
      onError: c.textPrimary,
    ),
    fontFamily: 'Outfit',
    appBarTheme: AppBarTheme(
      backgroundColor: c.bgSecondary,
      foregroundColor: c.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.borderDefault),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.linkAccent,
        foregroundColor: c.brightness == Brightness.dark
            ? const Color(0xFF0D1117)
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        side: BorderSide(color: c.borderDefault),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bgTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.linkAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
      labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borderDefault),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.bgTertiary,
      contentTextStyle: TextStyle(color: c.textPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.bgTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderDefault),
      ),
      textStyle: TextStyle(color: c.textPrimary, fontSize: 12),
    ),
    dividerTheme: DividerThemeData(
      color: c.borderDefault,
      thickness: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.linkAccent;
        return Colors.transparent;
      }),
      side: BorderSide(color: c.borderDefault, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

/// Styled UI helpers
class StyledWidgets {
  static Widget statusBadge(String status, AppColors c) {
    final color = c.getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget pathDisplay(String path, {Color? color, AppColors? c}) {
    return Text(
      path,
      style: TextStyle(
        fontFamily: 'Cascadia Code',
        fontSize: 11,
        color: color ?? c?.textSecondary ?? const Color(0xFF8B949E),
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
