@echo off
cd /d %~dp0
for %%i in (*.exe) do (
    start "" "%%i" -debug
    exit /b 0
)

echo [ERROR] No executable found in this folder.
pause
