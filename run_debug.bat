@echo off
cd /d %~dp0
echo ============================================================
echo  JA Sync Manager - Launching Executable in DEBUG Mode (-debug)
echo ============================================================
echo.

if exist "dist\ja_sync.exe" (
    start "" "dist\ja_sync.exe" -debug
) else if exist "build\windows\x64\runner\Release\ja_sync.exe" (
    start "" "build\windows\x64\runner\Release\ja_sync.exe" -debug
) else (
    echo [RUN] Running via flutter run -d windows...
    call flutter run -d windows -- -debug
)
