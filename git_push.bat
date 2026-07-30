@echo off
cd /d %~dp0

set /p remote_url="Nhap GitHub repo URL: "
set /p commit_msg="Nhap commit message: "
if "%commit_msg%"=="" set commit_msg=Update project

if exist "license.key" (
    echo [WARNING] Phat hien license.key. File nay phai nam trong .gitignore va khong duoc commit.
)

if not exist ".git" (
    git init
    git branch -M main
)

git status --short
git add .
git commit -m "%commit_msg%"
git remote remove origin 2>nul
git remote add origin "%remote_url%"
git push -u origin main

pause
