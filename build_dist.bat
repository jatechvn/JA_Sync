@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo Building JA Sync release package for Windows...
echo ===================================================

cd /d %~dp0

:: Stop any running copy so Flutter/CMake can overwrite DLLs and the EXE.
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

:: Read version from pubspec.yaml. Fallback keeps packaging usable if parsing fails.
set "APP_NAME=JA_Sync"
set "APP_EXE=ja_sync.exe"
set "APP_VERSION=1.1.0"
for /f "usebackq tokens=2 delims=:+" %%v in (`findstr /b /c:"version:" pubspec.yaml`) do (
    set "APP_VERSION=%%v"
)
set "APP_VERSION=%APP_VERSION: =%"

:: Run Flutter release build.
call flutter build windows --release

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Flutter build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ===================================================
echo Packaging release into dist/ directory...
echo ===================================================

:: Define paths
set "BUILD_RELEASE_DIR=build\windows\x64\runner\Release"
set "DIST_DIR=dist"
set "PACK_DIR=dist_pack"
set "ZIP_ROOT=%APP_NAME%_v%APP_VERSION%_Windows_x64"
set "ZIP_FILE=%DIST_DIR%\%ZIP_ROOT%.zip"

:: Remove existing dist directory to make it clean
if exist "%DIST_DIR%" (
    echo Cleaning existing %DIST_DIR% folder...
    rmdir /s /q "%DIST_DIR%"
)

:: Recreate dist directory
mkdir "%DIST_DIR%"

:: Copy all release files and directories
echo Copying files to %DIST_DIR%...
xcopy /s /e /y /q "%BUILD_RELEASE_DIR%\*" "%DIST_DIR%\"
if exist assets xcopy /s /e /y /q assets "%DIST_DIR%\assets\"
if exist i18n xcopy /s /e /y /q i18n "%DIST_DIR%\i18n\"
if exist ABOUT.txt copy /y ABOUT.txt "%DIST_DIR%\" >nul
if exist README.md copy /y README.md "%DIST_DIR%\" >nul
if exist USER_GUIDE.md copy /y USER_GUIDE.md "%DIST_DIR%\" >nul
if exist LICENSE copy /y LICENSE "%DIST_DIR%\" >nul
if exist debug.bat copy /y debug.bat "%DIST_DIR%\" >nul
if exist config.ini copy /y config.ini "%DIST_DIR%\" >nul

:: Check if build executable exists in dist
if exist "%DIST_DIR%\%APP_EXE%" (
    if exist "%PACK_DIR%" rmdir /s /q "%PACK_DIR%"
    mkdir "%PACK_DIR%\%ZIP_ROOT%"
    xcopy /s /e /y /q "%DIST_DIR%\*" "%PACK_DIR%\%ZIP_ROOT%\"
    if exist "%PACK_DIR%\%ZIP_ROOT%\*.zip" del /q "%PACK_DIR%\%ZIP_ROOT%\*.zip"
    if exist "%ZIP_FILE%" del /q "%ZIP_FILE%"
    powershell -NoProfile -Command "Compress-Archive -Path '%PACK_DIR%\*' -DestinationPath '%ZIP_FILE%' -Force"
    if exist "%PACK_DIR%" rmdir /s /q "%PACK_DIR%"
    echo.
    echo ===================================================
    echo [SUCCESS] Package created successfully in dist/
    echo Location: %cd%\dist
    echo ZIP: %ZIP_FILE%
    echo ===================================================
) else (
    echo.
    echo [ERROR] Failed to package files!
    pause
    exit /b 1
)

pause
