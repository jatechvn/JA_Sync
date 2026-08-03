# JA Sync Manager - 双向数据同步管理工具

JA Sync 是一款基于 **Flutter 3.x / Dart 3.x** 构建的高效桌面数据同步软件，支持 Windows 10 & 11、macOS 以及 Linux 平台上的双向镜像与单向镜像同步。

## 🚀 核心功能

- **智能双向同步**：基于 Manifest 与修改时间戳自动检测源与目标文件夹的变化。
- **数据安全与原子写入 (Atomic Copy)**：写入临时文件 `.ja_sync_tmp` 成功后再进行重命名，确保网络中断或断电时目标文件绝不损坏。
- **智能忽略垃圾文件**：自动排除开发与系统垃圾目录 (`.git`, `node_modules`, `__pycache__`, `$recycle.bin`, `.idea`, `.vscode` 等)。
- **Windows 10/11 亚克力与 Aero 模糊界面**：原生集成 Windows 11 Acrylic 亚克力与 Windows 10 Aero Blur 效果。
- **全局计划与限速控制**：支持实时、15分钟、1小时、12小时、24小时同步与带宽限速设置。
- **JSON 配置导入/导出**：方便在不同设备之间快速备份和迁移同步配置。
