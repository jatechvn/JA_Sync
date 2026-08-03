@echo off
setlocal enabledelayedexpansion
cd /d %~dp0
echo [BUILD] Compiling Windows desktop application in Release mode...
taskkill /IM ja_sync.exe /F >nul 2>nul

if exist "windows\flutter\ephemeral\.plugin_symlinks" (
    for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%t"
    echo [BUILD] Moving stale plugin symlinks aside...
    ren "windows\flutter\ephemeral\.plugin_symlinks" ".plugin_symlinks.bak_!STAMP!" >nul 2>nul
)

if exist "build\windows\x64\CMakeCache.txt" (
    for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%t"
    echo [BUILD] Moving stale Windows CMake cache aside...
    ren "build\windows" "windows.bak_!STAMP!" >nul 2>nul
)

call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo [LINK] Creating shortcut .Release.lnk to Release directory...
powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('.Release.lnk'); $s.TargetPath=(Get-Item 'build\windows\x64\runner\Release').FullName; $s.Save()"
echo [SUCCESS] Release build is complete. Shortcut .Release.lnk created.
pause
