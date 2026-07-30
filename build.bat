@echo off
cd /d %~dp0
echo [BUILD] Compiling Windows desktop application in Release mode...
call flutter build windows
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo [LINK] Creating shortcut .Release.lnk to Release directory...
powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('.Release.lnk'); $s.TargetPath=(Get-Item 'build\windows\x64\runner\Release').FullName; $s.Save()"
echo [SUCCESS] Release build is complete. Shortcut .Release.lnk created.
pause
