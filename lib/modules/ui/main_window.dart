// lib/modules/ui/main_window.dart
// Main application window interface for JA Sync with glassmorphism UI

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../logic.dart';
import '../i18n.dart';
import '../constants.dart';
import 'styles.dart';
import 'dialogs.dart';
import '../app_config.dart';
import '../build_info.dart';

class MainWindow extends StatefulWidget {
  final SyncLogic logic;
  final ThemeNotifier themeNotifier;
  final LanguageNotifier languageNotifier;

  const MainWindow({
    super.key,
    required this.logic,
    required this.themeNotifier,
    required this.languageNotifier,
  });

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> with WindowListener {
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initialize();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final closeAction = AppConfig.get('close_action');
    if (closeAction == 'minimize') {
      await windowManager.hide();
    } else if (closeAction == 'exit') {
      exit(0);
    } else {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: const CloseActionDialog(),
        ),
      );
      if (result == 'minimize') {
        await windowManager.hide();
      } else if (result == 'exit') {
        exit(0);
      }
    }
  }

  Future<void> _initialize() async {
    await widget.logic.initialize();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSyncPair() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: const AddSyncPairDialog(),
      ),
    );

    if (result != null) {
      await widget.logic.addPair(
        result['source'],
        result['target'],
        result['strategy'],
      );
    }
  }

  Future<void> _deleteSyncPair(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: const ConfirmDeleteDialog(),
      ),
    );

    if (confirm == true) {
      await widget.logic.removePair(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = LanguageProvider.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: c.bgPrimary,
        child: Column(
          children: [
            _buildHeaderBar(context, c, s),
            const Divider(height: 1),
            _buildDashboardAndSearchBar(context, c, s),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: c.linkAccent),
                          const SizedBox(height: 16),
                          Text(
                            s.msgLoading,
                            style: TextStyle(color: c.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListenableBuilder(
                      listenable: widget.logic,
                      builder: (context, _) {
                        if (widget.logic.states.isEmpty) {
                          return _buildEmptyState(c, s);
                        }
                        return _buildSyncPairsList(c, s);
                      },
                    ),
            ),
            const Divider(height: 1),
            _buildStatusBar(c, s),
          ],
        ),
      ),
    );
  }

  // ─── Header Bar ──────────────────────────────────────────────────────────

  Widget _buildHeaderBar(BuildContext context, AppColors c, AppStrings s) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: c.bgSecondary,
      child: Row(
        children: [
          // App Title
          Icon(Icons.sync_rounded, color: c.linkAccent, size: 26),
          const SizedBox(width: 10),
          Text(
            s.appTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          if (BuildInfo.isDebug) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.6),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bug_report_rounded,
                    size: 12,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'DEBUG • v${BuildInfo.version} (${BuildInfo.debugTimestamp})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),

          // Sync All Button
          ElevatedButton.icon(
            onPressed: (widget.logic.states.isEmpty ||
                    widget.logic.states.any((state) => state.config.schedule != 'manual'))
                ? null
                : () => widget.logic.syncAll(),
            icon: const Icon(Icons.sync_outlined, size: 16),
            label: Text(s.btnSyncAll),
          ),
          const SizedBox(width: 12),

          // Theme toggle
          IconButton(
            onPressed: () {
              widget.themeNotifier.toggle(Theme.of(context).brightness);
            },
            icon: Icon(widget.themeNotifier.modeIcon, color: c.textPrimary),
            tooltip: s.tooltipTheme(widget.themeNotifier.modeLabel),
          ),
          const SizedBox(width: 4),

          // Language toggle
          TextButton(
            onPressed: () {
              widget.languageNotifier.toggle();
            },
            style: TextButton.styleFrom(
              foregroundColor: c.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(40, 40),
            ),
            child: Row(
              children: [
                const Icon(Icons.language, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.languageNotifier.current.shortLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // History button
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: const HistoryDialog(),
                ),
              );
            },
            icon: Icon(Icons.history, color: c.textPrimary),
            tooltip: s.historyTitle,
          ),
          const SizedBox(width: 4),

          // Settings button
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: SettingsDialog(
                    themeNotifier: widget.themeNotifier,
                    languageNotifier: widget.languageNotifier,
                  ),
                ),
              );
            },
            icon: Icon(Icons.settings_outlined, color: c.textPrimary),
            tooltip: s.settingsTitle,
          ),
          const SizedBox(width: 12),

          // Plus Button (Add Pair)
          FloatingActionButton.small(
            onPressed: _addSyncPair,
            backgroundColor: c.linkAccent,
            foregroundColor: c.brightness == Brightness.dark
                ? const Color(0xFF0D1117)
                : Colors.white,
            elevation: 0,
            hoverElevation: 2,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppColors c, AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined, size: 64, color: c.textMuted),
          const SizedBox(height: 16),
          Text(
            s.emptyTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.emptySubtitle,
            style: TextStyle(
              fontSize: 13,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sync Pairs List ─────────────────────────────────────────────────────

  void _openFolderInExplorer(String path) {
    try {
      if (Directory(path).existsSync()) {
        Process.run('explorer.exe', [path]);
      }
    } catch (_) {}
  }

  Widget _buildDashboardAndSearchBar(BuildContext context, AppColors c, AppStrings s) {
    final totalPairs = widget.logic.states.length;
    final activeWatchers = widget.logic.states.where((st) => st.config.schedule == 'realtime').length;
    final syncingPairs = widget.logic.states.where((st) => st.status == statusSyncing || st.status == statusScanning).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: c.bgSecondary.withValues(alpha: 0.5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                s.lang == AppLanguage.vi
                    ? 'Tổng cặp đồng bộ'
                    : s.lang == AppLanguage.zh
                        ? '总同步配对'
                        : 'Total Pairs',
                '$totalPairs',
                Icons.folder_copy_outlined,
                c,
              ),
              _buildStatCard(
                s.lang == AppLanguage.vi
                    ? 'Bộ theo dõi (Realtime)'
                    : s.lang == AppLanguage.zh
                        ? '实时监控器'
                        : 'Active Watchers',
                '$activeWatchers',
                Icons.visibility_outlined,
                c,
              ),
              _buildStatCard(
                s.lang == AppLanguage.vi
                    ? 'Đang đồng bộ'
                    : s.lang == AppLanguage.zh
                        ? '正在同步'
                        : 'Syncing Now',
                '$syncingPairs',
                Icons.sync_rounded,
                c,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: s.lang == AppLanguage.vi
                          ? 'Tìm kiếm theo tên thư mục hoặc đường dẫn...'
                          : s.lang == AppLanguage.zh
                              ? '根据文件夹名称或路径搜索...'
                              : 'Search by folder name or path...',
                      prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.bgTertiary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.borderDefault),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    hint: Row(
                      children: [
                        Icon(Icons.date_range_rounded, color: c.linkAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          s.labelApplyScheduleAll,
                          style: TextStyle(color: c.textPrimary, fontSize: 13),
                        ),
                      ],
                    ),
                    dropdownColor: c.bgSecondary,
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                    icon: Icon(Icons.arrow_drop_down, color: c.textMuted),
                    items: [
                      DropdownMenuItem(value: 'manual', child: Text(s.optSchedManual)),
                      DropdownMenuItem(value: 'realtime', child: Text(s.optSchedRealtime)),
                      DropdownMenuItem(value: '15m', child: Text(s.optSched15m)),
                      DropdownMenuItem(value: '1h', child: Text(s.optSched1h)),
                      DropdownMenuItem(value: '12h', child: Text(s.optSched12h)),
                      DropdownMenuItem(value: '24h', child: Text(s.optSched24h)),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                            child: AlertDialog(
                              title: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: c.linkAccent),
                                  const SizedBox(width: 8),
                                  Text(s.lang == AppLanguage.vi
                                      ? 'Áp dụng cho tất cả'
                                      : s.lang == AppLanguage.zh
                                          ? '应用到所有'
                                          : 'Apply to All'),
                                ],
                              ),
                              content: Text(s.lang == AppLanguage.vi
                                  ? 'Bạn có chắc chắn muốn thay đổi lịch trình đồng bộ của tất cả các cặp thành chế độ đã chọn?'
                                  : s.lang == AppLanguage.zh
                                      ? '您确定要将所有配对的同步计划更改为所选模式吗？'
                                      : 'Are you sure you want to change the sync schedule of all pairs to the selected mode?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(s.btnCancel),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(s.btnConfirm),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (confirm == true) {
                          await widget.logic.updateAllSchedules(val);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(s.lang == AppLanguage.vi
                                    ? 'Đã áp dụng lịch trình đồng bộ cho tất cả các mục!'
                                    : s.lang == AppLanguage.zh
                                        ? '已应用同步计划到所有项！'
                                        : 'Applied sync schedule to all items!'),
                                backgroundColor: c.statusActive,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, AppColors c) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: c.bgCard.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: c.linkAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncPairsList(AppColors c, AppStrings s) {
    final filtered = widget.logic.states.where((state) {
      final q = _searchQuery.toLowerCase();
      return state.config.sourcePath.toLowerCase().contains(q) ||
          state.config.targetPath.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              s.lang == AppLanguage.vi
                  ? 'Không tìm thấy kết quả nào khớp!'
                  : s.lang == AppLanguage.zh
                      ? '没有找到匹配的结果！'
                      : 'No matching results found!',
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final state = filtered[index];
        final isBusy = state.status == statusSyncing ||
            state.status == statusScanning;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isBusy ? c.borderHighlight : c.borderDefault,
              width: isBusy ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Paths and Control actions
                Row(
                  children: [
                    // Paths display
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 75,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.linkAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    'SOURCE',
                                    style: TextStyle(
                                      color: c.linkAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StyledWidgets.pathDisplay(
                                    state.config.sourcePath,
                                    c: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.folder_open_outlined, size: 16),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                onPressed: () => _openFolderInExplorer(state.config.sourcePath),
                                tooltip: s.lang == AppLanguage.vi
                                    ? 'Mở thư mục nguồn'
                                    : s.lang == AppLanguage.zh
                                        ? '打开源文件夹'
                                        : 'Open source folder',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 75,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.targetAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    'TARGET',
                                    style: TextStyle(
                                      color: c.targetAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StyledWidgets.pathDisplay(
                                    state.config.targetPath,
                                    c: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.folder_open_outlined, size: 16),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                onPressed: () => _openFolderInExplorer(state.config.targetPath),
                                tooltip: s.lang == AppLanguage.vi
                                    ? 'Mở thư mục đích'
                                    : s.lang == AppLanguage.zh
                                        ? '打开目标文件夹'
                                        : 'Open target folder',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Status Badge
                    StyledWidgets.statusBadge(state.status, c),
                    const SizedBox(width: 16),

                    // Manual Sync Now Button
                    IconButton.filledTonal(
                      onPressed: (isBusy || state.config.schedule != 'manual')
                          ? null
                          : () => widget.logic.syncPair(state.config.id),
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: s.btnSyncNow,
                      style: IconButton.styleFrom(
                        foregroundColor: c.linkAccent,
                        backgroundColor: c.linkAccent.withValues(alpha: 0.12),
                      ),
                    ),

                    // Edit Settings Button
                    IconButton(
                      onPressed: isBusy
                          ? null
                          : () {
                              showDialog(
                                context: context,
                                builder: (_) => BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                  child: PairSettingsDialog(
                                    config: state.config,
                                    logic: widget.logic,
                                  ),
                                ),
                              );
                            },
                      icon: Icon(Icons.tune_rounded, color: c.linkAccent),
                      tooltip: s.btnPairSettings,
                    ),

                    // Remove Pair Button
                    IconButton(
                      onPressed: isBusy
                          ? null
                          : () => _deleteSyncPair(state.config.id),
                      icon: Icon(Icons.delete_outline, color: c.statusRemoved),
                      tooltip: s.btnDelete,
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),

                // Middle Row: Sync Mode, Schedule, Excludes and Strategy
                Row(
                  children: [
                    // Mode display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.bgTertiary,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.borderDefault),
                      ),
                      child: Text(
                        state.config.syncMode == 'one_way' ? s.optOneWay : s.optTwoWay,
                        style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Schedule display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.bgTertiary,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.borderDefault),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.config.schedule == 'realtime'
                                ? Icons.sync_disabled
                                : state.config.schedule == 'manual'
                                    ? Icons.touch_app_outlined
                                    : Icons.timer_outlined,
                            size: 12,
                            color: c.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            state.config.schedule == 'realtime'
                                ? s.optSchedRealtime
                                : state.config.schedule == 'manual'
                                    ? s.optSchedManual
                                    : state.config.schedule == '15m'
                                        ? s.optSched15m
                                        : state.config.schedule == '1h'
                                            ? s.optSched1h
                                            : state.config.schedule == '12h'
                                                ? s.optSched12h
                                                : s.optSched24h,
                            style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Strategy Dropdown
                    Row(
                      children: [
                        Text(
                          '${s.labelConflictStrategy}:',
                          style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.bgTertiary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: state.config.conflictStrategy,
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              isDense: true,
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
                              onChanged: isBusy
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        widget.logic.updateConflictStrategy(
                                            state.config.id, val);
                                      }
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bottom Row: Progress Indicators or metadata
                if (isBusy) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.progress > 0 ? state.progress : null,
                      color: c.linkAccent,
                      backgroundColor: c.bgTertiary,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          state.statusMessage,
                          style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(state.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: c.linkAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (state.currentFile.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      state.currentFile,
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.statusMessage.isNotEmpty
                            ? state.statusMessage
                            : '',
                        style: TextStyle(
                            color: state.status == statusError
                                ? c.statusRemoved
                                : c.textSecondary,
                            fontSize: 12),
                      ),
                      Text(
                        state.config.lastSyncTime.isNotEmpty
                            ? 'Last Sync: ${state.config.lastSyncTime}'
                            : 'Last Sync: Never',
                        style: TextStyle(color: c.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Status Bar ──────────────────────────────────────────────────────────

  Widget _buildStatusBar(AppColors c, AppStrings s) {
    final pairsCount = widget.logic.states.length;
    final activeWatchersCount = widget.logic.states
        .where((state) => state.config.autoSync)
        .length;

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: c.bgSecondary,
      child: Row(
        children: [
          // Total pairs
          Icon(Icons.folder_special, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          Text(
            'Pairs: $pairsCount',
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
          const SizedBox(width: 20),

          // Active watchers
          Icon(Icons.remove_red_eye_outlined, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          Text(
            'Watching: $activeWatchersCount',
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
          const Spacer(),

          // Status label
          Text(
            appName,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
