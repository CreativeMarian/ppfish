@echo off
rem ppfish 打包上传工具 - 双击运行
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0打包上传.ps1" %*
echo.
pause
