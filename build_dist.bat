@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo Building JA Sync for Windows...
echo ===================================================

:: Run flutter build windows
call flutter build windows

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

:: Check if build executable exists in dist
if exist "%DIST_DIR%\ja_sync.exe" (
    echo.
    echo ===================================================
    echo [SUCCESS] Package created successfully in dist/
    echo Location: %cd%\dist
    echo ===================================================
) else (
    echo.
    echo [ERROR] Failed to package files!
    pause
    exit /b 1
)

pause
