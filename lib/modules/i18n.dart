// lib/modules/i18n.dart
// Multi-language support for JA Sync (English / 中文 / Tiếng Việt)

import 'package:flutter/material.dart';
import 'app_config.dart';

enum AppLanguage { en, zh, vi }

extension AppLanguageExt on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.en:
        return 'en';
      case AppLanguage.zh:
        return 'zh';
      case AppLanguage.vi:
        return 'vi';
    }
  }

  String get shortLabel {
    switch (this) {
      case AppLanguage.en:
        return 'EN';
      case AppLanguage.zh:
        return '中';
      case AppLanguage.vi:
        return 'VN';
    }
  }

  String get fullLabel {
    switch (this) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.zh:
        return '中文';
      case AppLanguage.vi:
        return 'Tiếng Việt';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'zh':
        return AppLanguage.zh;
      case 'vi':
        return AppLanguage.vi;
      default:
        return AppLanguage.en;
    }
  }

  AppLanguage get next {
    final values = AppLanguage.values;
    return values[(index + 1) % values.length];
  }
}

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  String _s(String en, String zh, String vi) {
    switch (lang) {
      case AppLanguage.zh:
        return zh;
      case AppLanguage.vi:
        return vi;
      default:
        return en;
    }
  }

  // App UI Strings
  String get appTitle =>
      _s('JA Sync Manager', 'JA 同步管理器', 'Trình quản lý đồng bộ JA');
  String get filterAll => _s('ALL', '全部', 'Tất cả');
  String get btnAddPair => _s('Add Pair', '添加配对', 'Thêm cặp');
  String get btnSyncAll => _s('Sync All', '全部同步', 'Đồng bộ tất cả');
  String get btnCancel => _s('Cancel', '取消', 'Hủy');
  String get btnAdd => _s('Add', '添加', 'Thêm');
  String get btnSave => _s('Save', '保存', 'Lưu');
  String get btnDelete => _s('Delete', '删除', 'Xóa');
  String get btnBrowse => _s('Browse', '浏览', 'Duyệt');
  String get btnSyncNow => _s('Sync Now', '立即同步', 'Đồng bộ ngay');
  String get labelSource => _s('Source Path', '源路径', 'Đường dẫn nguồn');
  String get labelTarget => _s('Target Path', '目标路径', 'Đường dẫn đích');
  String get labelConflictStrategy =>
      _s('Conflict Strategy', '冲突策略', 'Chiến lược xung đột');
  String get labelAutoSync =>
      _s('Auto Sync', '自动同步', 'Tự động đồng bộ');
  String get labelTheme => _s('Theme', '主题', 'Giao diện');
  String get labelLanguage => _s('Language', '语言', 'Ngôn ngữ');
  String get labelStatus => _s('STATUS', '状态', 'TRẠNG THÁI');
  String get labelProgress => _s('PROGRESS', '进度', 'TIẾN TRÌNH');
  String get labelActions => _s('ACTIONS', '操作', 'THAO TÁC');
  String get emptyTitle =>
      _s('No sync pairs configured', '未配置同步配对', 'Chưa cấu hình cặp đồng bộ nào');
  String get emptySubtitle => _s('Click "+" to add a new sync pair',
      '点击 "+" 添加新的同步配对', 'Nhấn "+" để thêm cặp đồng bộ mới');
  String get strategyNewerWins =>
      _s('Newer Wins', '最新文件优先', 'File mới hơn thắng');
  String get strategySourceWins =>
      _s('Source Wins', '源文件夹优先', 'Nguồn thắng');
  String get strategyTargetWins =>
      _s('Target Wins', '目标文件夹优先', 'Đích thắng');
  String get msgLoading => _s('Loading...', '加载中...', 'Đang tải...');
  String get msgSyncing => _s('Syncing...', '正在同步...', 'Đang đồng bộ...');
  String get msgScanning =>
      _s('Scanning folders...', '正在扫描文件夹...', 'Đang quét thư mục...');
  String get msgDeleting =>
      _s('Deleting file: ', '正在删除文件: ', 'Đang xóa file: ');
  String get msgCopying =>
      _s('Copying file: ', '正在复制文件: ', 'Đang copy file: ');
  String get msgCompleted =>
      _s('Sync completed successfully!', '同步成功完成！', 'Đồng bộ hoàn tất thành công!');
  String get msgError => _s('Sync failed: ', '同步失败: ', 'Đồng bộ thất bại: ');
  String get labelConflict => _s('Conflict', '冲突', 'Xung đột');
  String get tooltipRefresh => _s('Refresh', '刷新', 'Làm mới');
  String get tooltipLanguage => _s('Language', '语言', 'Ngôn ngữ');
  String tooltipTheme(String modeName) =>
      _s('Theme: $modeName', '主题: $modeName', 'Giao diện: $modeName');
  String get themeDark => _s('Dark', '深色', 'Tối');
  String get themeLight => _s('Light', '浅色', 'Sáng');
  String get themeAuto => _s('Auto', '自动', 'Tự động');
  String get confirmDeleteTitle =>
      _s('Remove Sync Pair', '删除同步配对', 'Xóa cặp đồng bộ');
  String get confirmDeleteDesc => _s(
      'Are you sure you want to remove this sync pair? This will NOT delete any files inside the folders.',
      '您确定要删除此同步配对吗？这不会删除文件夹内的任何文件。',
      'Bạn có chắc muốn xóa cặp đồng bộ này? Việc này sẽ KHÔNG xóa bất kỳ file nào trong thư mục.');
  String get dlgCloseTitle => _s('Exit Option', '退出选项', 'Tùy chọn thoát');
  String get dlgCloseDesc => _s(
      'What would you like to do when closing the application?',
      '关闭应用程序时您想做什么？',
      'Bạn muốn làm gì khi đóng ứng dụng?');
  String get optMinimizeToTray => _s(
      'Minimize to system tray (keep running)',
      '最小化到系统托盘 (继续运行)',
      'Thu nhỏ xuống khay hệ thống (vẫn chạy ngầm)');
  String get optExitApp => _s(
      'Exit application completely',
      '完全退出应用程序',
      'Thoát ứng dụng hoàn toàn');
  String get labelRememberChoice => _s('Remember my choice', '记住我的选择', 'Ghi nhớ lựa chọn này');
  String get btnConfirm => _s('Confirm', '确认', 'Xác nhận');
  String get trayShowWindow => _s('Show Window', '显示窗口', 'Hiện cửa sổ');
  String get trayExit => _s('Exit', '退出', 'Thoát');
  String get settingsTitle => _s('Settings', '设置', 'Cài đặt');
  String get secGeneral => _s('General', '常规', 'Cài đặt chung');
  String get secInterface => _s('Interface', '界面', 'Giao diện');
  String get labelStartWithWindows => _s('Start with Windows', '开机自启动', 'Khởi động cùng Windows');
  String get labelStartMinimized => _s('Start minimized to system tray', '启动时最小化到系统托盘', 'Khởi động thu nhỏ vào khay hệ thống');
  String get labelCloseAction => _s('When closing window', '关闭窗口时', 'Hành động khi đóng');
  String get optCloseAsk => _s('Ask every time', '每次询问', 'Hỏi mỗi lần đóng');
  String get optCloseMinimize => _s('Minimize to system tray', '最小化到系统托盘', 'Thu nhỏ vào khay hệ thống');
  String get optCloseExit => _s('Exit application', '完全退出', 'Thoát hoàn toàn');
  String get labelSpeedLimit => _s('Speed Limit', '速度限制', 'Giới hạn tốc độ');
  String get labelSyncMode => _s('Sync Mode', '同步模式', 'Chế độ đồng bộ');
  String get labelSchedule => _s('Sync Schedule', '同步计划', 'Lịch trình đồng bộ');
  String get labelExcludes => _s('Exclude files (comma separated)', '排除文件 (逗号分隔)', 'Bộ lọc loại bỏ (phân cách bằng dấu phẩy)');
  String get optTwoWay => _s('Two-Way Sync', '双向同步', 'Đồng bộ hai chiều');
  String get optOneWay => _s('One-Way Mirror', '单向镜像', 'Đồng bộ một chiều');
  String get btnPairSettings => _s('Filter & Mode', '过滤与模式', 'Bộ lọc & Chế độ');
  String get historyTitle => _s('Sync History', '同步历史', 'Lịch sử đồng bộ');
  String get historyEmpty => _s('No sync actions recorded yet', '暂无同步历史记录', 'Chưa có lịch sử đồng bộ nào');
  String get optSchedManual => _s('Manual only', '仅手动', 'Chỉ thủ công');
  String get optSchedRealtime => _s('Real-time', '实时监控', 'Thời gian thực');
  String get optSched15m => _s('Every 15 minutes', '每 15 分钟', 'Mỗi 15 phút');
  String get optSched1h => _s('Every 1 hour', '每 1 小时', 'Mỗi 1 giờ');
  String get optSched12h => _s('Every 12 hours', '每 12 小时', 'Mỗi 12 giờ');
  String get optSched24h => _s('Every 24 hours', '每 24 小时', 'Mỗi 24 giờ');
  String get errPathEmpty =>
      _s('Paths cannot be empty', '路径不能为空', 'Đường dẫn không được để trống');
  String get errPathNotExist =>
      _s('Path does not exist on disk', '路径在磁盘上不存在', 'Đường dẫn không tồn tại trên đĩa');
  String get errPathSame => _s('Source and Target cannot be identical',
      '源与目标不能相同', 'Nguồn và Đích không được giống nhau');
  String get warnNetworkPathRealtime => _s(
      'Real-time sync on network paths (UNC) may be unstable. Periodic schedule is recommended.',
      '在网络路径(UNC)上进行实时同步可能会不稳定。建议使用定期同步。',
      'Đồng bộ thời gian thực trên đường dẫn mạng (UNC) có thể không ổn định. Khuyên dùng lịch trình định kỳ.');
  
  String get labelApplyScheduleAll => _s(
      'Apply schedule to all',
      '应用计划到所有',
      'Áp dụng lịch trình cho tất cả');
  String get labelAboutGuide => _s(
      'About & Guide',
      '关于与指南',
      'Giới thiệu & Hướng dẫn');
  String get aboutContent => _s(
      r'''JA Sync Manager (v1.2.0) is a professional, high-performance, and ultra-secure file synchronization application.

Key Features & Highlights:
• Two-Way Sync: Intelligently synchronizes file additions, modifications, and deletions between two directories.
• One-Way Mirror: Keeps the Target directory as an exact, automated mirror copy of the Source directory.
• Sync Profiles: Apply built-in presets (Backup Mirror, Bi-Directional, Archive) or save your own settings as a reusable profile.
• Dry-Run Preview: See exactly what a sync would copy, delete, or create before it runs — no files are touched.
• Maximum Data Safety (Atomic Copy): Streams files into atomic temporary files (.ja_sync_tmp) before finalizing to guarantee target files are never corrupted during sudden power or network outages.
• Smart Auto-Exclusions: Automatically skips developer cache & OS junk folders (.git, node_modules, __pycache__, $recycle.bin, Office lock files ~$...).
• Premium Windows 10/11 Glassmorphism UI: Fully integrated with native Windows 11 Acrylic & Windows 10 Aero Blur aesthetics.''',

      r'''JA Sync Manager (v1.2.0) 是一款专业、高效且绝对安全的文件数据同步工具。

核心特色与优势：
• 双向智能同步 (Two-Way Sync)：智能检测并双向同步源与目标文件夹中的新增、修改与删除操作。
• 单向镜像同步 (One-Way Mirror)：使目标文件夹保持为源文件夹的精确镜像副本。
• 同步配置模板 (Sync Profiles)：应用内置模板（镜像备份、双向、归档）或将当前设置保存为可复用模板。
• 预览同步 (Dry-Run Preview)：在执行前查看将要复制、删除或创建的内容，不会更改任何文件。
• 原子级写入安全保障 (Atomic Copy)：写入临时文件 (.ja_sync_tmp) 验证成功后再重命名，即使遭遇突发断电或断网，目标文件也绝不会损坏。
• 智能垃圾过滤 (Smart Ignore)：自动排除系统与开发缓存垃圾 (.git, node_modules, __pycache__, $recycle.bin, Office 临时锁定文件 ~$...)。
• Windows 10/11 高级 Glassmorphism 界面：原生集成 Windows 11 亚克力 (Acrylic) 与 Windows 10 Aero Blur 晶莹磨砂效果。''',

      r'''JA Sync Manager (v1.2.0) là giải pháp đồng bộ hóa dữ liệu chuyên nghiệp, hiệu năng cao và an toàn tuyệt đối dành cho máy tính.

Tính năng nổi bật & Ưu điểm:
• Đồng bộ Hai Chiều (Two-Way Sync): Tự động cập nhật dữ liệu qua lại giữa hai thư mục một cách thông minh và nhất quán.
• Đồng bộ Một Chiều (One-Way Mirror): Biến thư mục Đích thành bản sao chính xác tuyệt đối của thư mục Nguồn.
• Hồ sơ đồng bộ (Sync Profiles): Áp dụng mẫu có sẵn (Sao lưu Mirror, Hai chiều, Lưu trữ) hoặc lưu cài đặt hiện tại thành hồ sơ để tái sử dụng.
• Xem trước đồng bộ (Dry-Run Preview): Xem chính xác những gì sẽ được sao chép, xóa, hoặc tạo mới trước khi chạy thật — không đụng đến file nào.
• An toàn dữ liệu tối đa (Atomic Copy): Ghi dữ liệu thông qua file tạm nguyên tử (.ja_sync_tmp) chống hỏng file ngay cả khi mất điện hay mất kết nối mạng bất ngờ.
• Bộ lọc thông minh tự động (Smart Ignore): Tự động loại bỏ rác hệ thống & lập trình (.git, node_modules, __pycache__, $recycle.bin, file tạm Office ~$...).
• Giao diện Glassmorphism Windows 10/11: Hỗ trợ hiệu ứng kính mờ Acrylic (Win11) & Aero Blur (Win10) hiện đại, mượt mà và sang trọng.''');

  String get guideContent => _s(
      r'''USER GUIDE & OPERATIONAL STEPS:

1. Add a New Sync Pair:
   • Click the plus (+) button at the top-right header bar.
   • Browse and select your Source folder and Target folder.
   • Choose your initial sync strategy and click "Add Pair".

2. Customize Sync Strategy & Schedule:
   • Click the "Pair Settings" button (gear icon next to each sync pair).
   • Two-Way Sync: Keeps both folders updated. Accidental deletions are prevented unless explicitly deleted at Source or Target.
   • One-Way Mirror: Makes Target an exact replica of Source. Extra files in Target will be removed to match Source.
   • Schedule: Choose "Real-time" for instant background synchronization, or select a periodic interval (15m, 1h, 12h, 24h, Manual).

3. Bandwidth Throttling & Visual Customization:
   • Under the "Advanced" Settings tab, set a Speed Limit (e.g. 1 MB/s, 5 MB/s) to preserve local network performance.
   • Use the Glassmorphism sliders to adjust background Blur and Opacity levels.

4. Backup & Migration:
   • Export your configured sync pairs to a JSON file and import them anytime on another PC.''',
      
      r'''使用指南与操作步骤：

1. 添加新同步配对：
   • 点击右上角标题栏上的加号 (+) 按钮。
   • 浏览并选择源文件夹 (Source) 和目标文件夹 (Target)。
   • 选择初始同步模式，然后点击“添加配对”。

2. 自定义同步模式与计划：
   • 点击每个同步配对旁边的“配对设置”按钮（齿轮图标）。
   • 双向同步 (Two-Way)：保持两个文件夹同步更新。有效防止误删，除非在源或目标显式删除。
   • 单向镜像 (One-Way Mirror)：以源文件夹为准，目标文件夹中的多余文件将被删除以保持完全一致。
   • 同步计划：选择“实时”(Real-time) 以在文件更改时即时同步，或选择定期时间间隔 (15m, 1h, 12h, 24h, 手动)。

3. 带宽限速与界面自定义：
   • 在“高级设置”选项卡中，设置传输限速 (如 1 MB/s, 5 MB/s)，以免占用局域网带宽。
   • 使用 Glassmorphism 滑块自定义背景模糊度 (Blur) 与透明度 (Opacity)。

4. 配置备份与迁移：
   • 将已配置的同步配对导出为 JSON 文件，并可随时在其他电脑上重新导入。''',
      
      r'''HƯỚNG DẪN SỬ DỤNG VÀ THAO TÁC:

1. Thêm Cặp Đồng Bộ Mới:
   • Nhấn vào nút dấu cộng (+) ở góc trên bên phải thanh công cụ.
   • Chọn thư mục Nguồn (Source) và thư mục Đích (Target) cần đồng bộ.
   • Chọn chế độ mặc định (Hai chiều hoặc Một chiều) và nhấn "Thêm cặp".

2. Tùy Chỉnh Chế Độ & Lịch Trình Đồng Bộ:
   • Nhấn nút "Cài đặt cặp" (biểu tượng bánh răng ở từng dòng cặp đồng bộ).
   • Chế độ Hai chiều (Two-Way): Cập nhật thay đổi từ cả 2 phía. Chống xóa nhầm dữ liệu trừ khi bạn chủ động nhấn xóa ở Nguồn hoặc Đích.
   • Chế độ Một chiều (One-Way Mirror): Nguồn là chuẩn. Thư mục Đích sẽ tự động xóa các file không có ở Nguồn.
   • Lịch trình: Chọn "Thời gian thực" (Real-time) để ứng dụng tự động đồng bộ ngay lập tức khi file thay đổi, hoặc chọn khoảng thời gian (15m, 1h, 12h, 24h, Thủ công).

3. Giới Hạn Băng Thông & Tùy Chỉnh Giao Diện:
   • Trong tab "Cài đặt" của ứng dụng, bạn có thể chỉnh Tốc độ giới hạn băng thông (1 MB/s, 5 MB/s...) để không làm chậm mạng LAN.
   • Điều chỉnh độ mờ (Blur) và độ trong suốt (Opacity) của ứng dụng theo sở thích.

4. Nhập & Xuất Cấu Hình:
   • Dễ dàng sao lưu danh sách cặp đồng bộ bằng cách nhấn "Xuất" file JSON và "Nhập" lại trên máy tính khác.''');

  String get btnClose => _s('Close', '关闭', 'Đóng');

  // --- Sync Profiles ---
  String get labelApplyProfile =>
      _s('Apply Profile (optional)', '应用配置模板（可选）', 'Áp dụng hồ sơ (tùy chọn)');
  String get optNoProfile =>
      _s('None - Custom Settings', '无 - 自定义设置', 'Không - Tùy chỉnh');
  String get profileNameBackupMirror =>
      _s('Backup (Mirror)', '备份（镜像）', 'Sao lưu (Mirror)');
  String get profileDescBackupMirror => _s(
      'One-way copy, source is always right, manual trigger',
      '单向复制，源文件夹始终优先，手动触发',
      'Sao chép một chiều, nguồn luôn đúng, chạy thủ công');
  String get profileNameBiDirectional =>
      _s('Bi-Directional (Realtime)', '双向（实时）', 'Hai chiều (Thời gian thực)');
  String get profileDescBiDirectional => _s(
      'Two-way sync, newer file wins, watches for changes live',
      '双向同步，最新文件优先，实时监控变化',
      'Đồng bộ hai chiều, file mới hơn thắng, theo dõi thay đổi tức thời');
  String get profileNameArchive => _s('Archive', '归档', 'Lưu trữ');
  String get profileDescArchive => _s(
      'One-way copy, target is always right, syncs once a day',
      '单向复制，目标文件夹始终优先，每天同步一次',
      'Sao chép một chiều, đích luôn đúng, đồng bộ mỗi ngày một lần');
  String get btnManageProfiles => _s('Manage Profiles', '管理配置模板', 'Quản lý hồ sơ');
  String get profilesDialogTitle => _s('Sync Profiles', '同步配置模板', 'Hồ sơ đồng bộ');
  String get labelBuiltInProfiles => _s('Built-in', '内置', 'Có sẵn');
  String get labelCustomProfiles => _s('Custom', '自定义', 'Tùy chỉnh');
  String get btnSaveAsProfile =>
      _s('Save as Profile', '另存为配置模板', 'Lưu thành hồ sơ');
  String get dlgSaveProfileTitle =>
      _s('Save Profile', '保存配置模板', 'Lưu hồ sơ');
  String get labelProfileName => _s('Profile Name', '模板名称', 'Tên hồ sơ');
  String get errProfileNameEmpty =>
      _s('Profile name cannot be empty', '模板名称不能为空', 'Tên hồ sơ không được để trống');
  String get errProfileNameExists => _s(
      'A profile with this name already exists',
      '已存在同名模板',
      'Đã tồn tại hồ sơ với tên này');
  String get msgProfileSaved => _s('Profile saved!', '模板已保存！', 'Đã lưu hồ sơ!');
  String get confirmDeleteProfileDesc => _s(
      'Are you sure you want to delete this custom profile?',
      '您确定要删除此自定义模板吗？',
      'Bạn có chắc muốn xóa hồ sơ tùy chỉnh này?');
  String get emptyCustomProfiles =>
      _s('No custom profiles yet', '暂无自定义模板', 'Chưa có hồ sơ tùy chỉnh nào');

  // --- Dry-Run / Preview Sync ---
  String get btnPreviewSync => _s('Preview Sync', '预览同步', 'Xem trước đồng bộ');
  String get previewDialogTitle =>
      _s('Sync Preview', '同步预览', 'Xem trước đồng bộ');
  String get previewLoading =>
      _s('Scanning for differences...', '正在扫描差异...', 'Đang quét khác biệt...');
  String get previewNoChanges => _s(
      'No changes detected. Everything is already in sync.',
      '未检测到任何变化，一切都已同步。',
      'Không phát hiện thay đổi nào. Mọi thứ đã được đồng bộ.');
  String get previewErrorPaths => _s(
      'Cannot preview: source or target folder is inaccessible.',
      '无法预览：源文件夹或目标文件夹无法访问。',
      'Không thể xem trước: thư mục nguồn hoặc đích không thể truy cập.');
  String previewSummary(int copyCount, int deleteCount, int dirCount) => _s(
      '$copyCount to copy · $deleteCount to delete · $dirCount folders to create',
      '$copyCount 个待复制 · $deleteCount 个待删除 · $dirCount 个待创建文件夹',
      '$copyCount tệp cần sao chép · $deleteCount tệp cần xóa · $dirCount thư mục cần tạo');
  String get previewActionCopyToTarget =>
      _s('Copy to Target', '复制到目标', 'Sao chép sang Đích');
  String get previewActionCopyToSource =>
      _s('Copy to Source', '复制到源', 'Sao chép sang Nguồn');
  String get previewActionDeleteFromTarget =>
      _s('Delete from Target', '从目标删除', 'Xóa khỏi Đích');
  String get previewActionDeleteFromSource =>
      _s('Delete from Source', '从源删除', 'Xóa khỏi Nguồn');
  String get previewActionCreateFolder =>
      _s('Create folder', '创建文件夹', 'Tạo thư mục');
}

/// Resolves a profile's display name/description: built-in profiles are
/// translated by key; custom profiles just show their user-given name.
extension SyncProfileDisplay on SyncProfile {
  String displayName(AppStrings s) {
    switch (key) {
      case 'backup_mirror':
        return s.profileNameBackupMirror;
      case 'bi_directional':
        return s.profileNameBiDirectional;
      case 'archive':
        return s.profileNameArchive;
      default:
        return key;
    }
  }

  String displayDescription(AppStrings s) {
    switch (key) {
      case 'backup_mirror':
        return s.profileDescBackupMirror;
      case 'bi_directional':
        return s.profileDescBiDirectional;
      case 'archive':
        return s.profileDescArchive;
      default:
        return '';
    }
  }
}

class LanguageNotifier extends ChangeNotifier {
  AppLanguage _current;
  LanguageNotifier(this._current);

  AppLanguage get current => _current;
  AppStrings get strings => AppStrings(_current);

  void changeLanguage(AppLanguage newLang) {
    if (newLang != _current) {
      _current = newLang;
      AppConfig.set('language', newLang.code);
      notifyListeners();
    }
  }

  void toggle() {
    changeLanguage(_current.next);
  }
}

class LanguageProvider extends InheritedNotifier<LanguageNotifier> {
  const LanguageProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppStrings of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<LanguageProvider>();
    return provider?.notifier?.strings ?? const AppStrings(AppLanguage.en);
  }

  static LanguageNotifier notifierOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<LanguageProvider>();
    return provider!.notifier!;
  }
}
