# 🔄 JA_Sync

<p align="center">
  <br>
  <i>**High Performance Local Folder Synchronization Tool for Windows**</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-informational.svg?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue.svg?style=flat-square" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-blue.svg?style=flat-square" alt="Dart">
</p>

<p align="center"><a href="#quick-start">🚀 Quick Start</a> • <a href="#features">💡 Features</a> • <a href="USER_GUIDE.md">📖 User Guide</a> • <a href="CHANGELOG.md">📝 Changelog</a> • <a href="https://jatechvn.github.io/">🌐 Website</a></p>

---

## Introduction

**JA Sync** is a professional desktop application designed to efficiently synchronize files and folders locally on Windows. Built with **Flutter** and **Dart**, it features a beautiful, customizable Glassmorphism user interface and an extremely fast, asynchronous synchronization engine capable of handling hundreds of thousands of files without freezing.

## 💡 Key Features

- **Blazing Fast Sync Engine**: Utilizes asynchronous Dart Streams and batched operations for zero-block UI rendering.
- **Smart System Exclusions**: Automatically skips build cache directories (`build`, `.dart_tool`, `node_modules`, `.git`, `.plugin_symlinks`, etc.) to save time and CPU.
- **Beautiful Glassmorphism UI**: Stunning Windows 11-style Acrylic/Mica transparent effects, fully customizable blur and opacity.
- **Two-Way & One-Way Sync**: Safely sync changes from Source to Target, or bi-directionally with conflict resolution strategies (Newer Wins, Source Wins, Target Wins).
- **Sync Profiles**: Apply built-in presets (Backup Mirror, Bi-Directional, Archive) or save your own pair settings as a reusable profile.
- **Dry-Run Preview**: Preview exactly what a sync would copy, delete, or create before committing to it — no files are touched.
- **Atomic Operations**: Files are copied to temporary buffers and renamed atomically to prevent data corruption during unexpected power losses.
- **Detailed Sync History**: Logs every copied, deleted, or skipped file in a structured JSON log.

---

## Directory Structure

```text
JA_Sync/
├── lib/                       # Flutter/Dart Source Code
│   ├── main.dart              # Application entry point
│   ├── modules/               # Core business logic & UI components
│   └── services/              # Background services
├── assets/                    # Static resources (icons, images)
├── dist/                      # Pre-compiled Windows Executables (Release)
├── test/                      # Unit tests
├── pubspec.yaml               # Flutter package dependencies and version
├── README.md                  # Project documentation (this file)
├── CHANGELOG.md               # Version history
├── USER_GUIDE.md              # Detailed User Guide
├── ABOUT.txt                  # Project information card
└── LICENSE                    # MIT License
```

---

<a id="quick-start"></a>
## 🚀 Quick Start (Pre-compiled)

1. Open the `dist/` directory.
2. Run `ja_sync.exe` to launch the application normally.
3. Or run `debug.bat` to launch the application with the debug console attached.

## 🛠️ Development Setup

If you want to build the project from source:

### System Requirements
*   OS: **Windows 10/11**
*   Environment: **Flutter SDK 3.19+**, **Dart 3.3+**, **Visual Studio Build Tools 2022+**

### How to Build

1. Run `flutter pub get` to install dependencies.
2. Run `build.bat` in the project root to compile a Release build for Windows.
3. The output will be located in `build\windows\x64\runner\Release\`.
4. Copy the compiled files to `dist/` using the script `build_dist.bat` (if available).

---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
