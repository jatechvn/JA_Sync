# 📖 JA Sync - User Guide

Welcome to the **JA Sync** User Guide! This document explains how to set up and use the synchronization features of the application.

## 1. Getting Started

### Launching the Application
You can run the application directly by executing `ja_sync.exe` inside the `dist/` directory. 
If you need to view internal logs or debug errors, run `debug.bat` instead.

### Interface Overview
When you open JA Sync, you will see a beautifully designed Glassmorphism interface containing:
- **Left Sidebar**: Controls your sync pairs, allows you to add new pairs, and access App Settings.
- **Main Sync Area**: Displays the sync progress, source/target directories, and control buttons for the currently selected pair.
- **Top Header**: Displays the application status and build information.

---

## 2. Managing Sync Pairs

A "Sync Pair" is a configuration that defines a relationship between two directories: a **Source** and a **Target**.

### Adding a New Sync Pair
1. Click the **"+"** (Add) button on the left sidebar.
2. The application will create a new sync pair with default settings.
3. Select the pair, and use the **Browse** buttons (Folder icons) to select your `Source` directory and `Target` directory.

### Sync Modes
- **Two-Way Sync**: Changes in the Source are mirrored to the Target, and changes in the Target are mirrored to the Source. 
- **One-Way (Source to Target)**: Only changes from the Source are copied to the Target. Changes in the Target are ignored.

### Conflict Resolution Strategy
When both the Source file and the Target file have been modified since the last sync, a conflict occurs. You can configure how the app resolves conflicts:
- **Newer Wins (Recommended)**: The file with the most recent modification time overwrites the older file.
- **Source Wins**: The file in the Source directory always overwrites the Target file.
- **Target Wins**: The file in the Target directory always overwrites the Source file.

### Advanced Settings (Exclusions)
You can configure filters to exclude specific folders or files from being synced:
1. Click the **Settings (Gear)** icon on the Sync Pair card.
2. In the "Excludes" text box, enter folder names or file names you want to ignore (e.g., `build, .git, node_modules`).
3. These filters are combined with the global system excludes to ensure optimal performance.

---

## 3. Performing a Synchronization

1. Select your desired Sync Pair from the sidebar.
2. Review the Source and Target paths.
3. Click the **Start Sync** (Play icon) button.
4. The application will:
   - Scan both directories asynchronously.
   - Skip ignored files to save CPU and Disk usage.
   - Calculate changes and copy files atomically (saving to a temporary `.ja_sync_tmp` file first to prevent corruption).
   - Display real-time progress on the progress bar.
   - Clean up any empty directories.
5. Once finished, the status will show **"Sync completed successfully!"**.

---

## 4. Application Settings

Click the **Settings (Gear)** icon at the bottom of the left sidebar to access global application settings:
- **Language**: Switch between supported languages.
- **Theme**: Toggle between Light and Dark mode.
- **Glassmorphism Settings**: Adjust the Blur and Opacity of the acrylic window background to your liking.
- **Start with Windows**: Toggle whether JA Sync should launch automatically when you boot your PC.

---

## 5. Troubleshooting & Logs

If a file fails to copy or the app behaves unexpectedly:
1. Open the `dist/logs/` directory.
2. Check `debug_YYYY-MM-DD.log` for detailed system events and stack traces.
3. Check `sync_history.json` for a structured log of every file operation (Copy/Delete) during the last sync.
