@echo off
REM ============================================================
REM Yanler APK 自动同步 — 安装脚本
REM 用法：双击运行
REM 安装内容：
REM   1) 计划任务 YanlerApkSync（每 6 小时自动检查同步）
REM   2) 启动文件夹脚本（每次登录自动同步一次）
REM 有新版本时自动下载并替换 D:\apk 下的旧 APK。
REM 卸载：
REM   schtasks /delete /f /tn "YanlerApkSync"
REM   删除 %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\yanler_apk_sync.cmd
REM ============================================================

set SCRIPT=D:\search\yanler_browser\tool\sync_apk.py
set PYTHON=C:\Users\lenovo\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe
set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup

if not exist "%PYTHON%" (
    echo [错误] 未找到 %PYTHON%
    echo 请将本文件 PYTHON 变量改为你机器上 Python 3.8+ 的完整路径
    pause
    exit /b 1
)

echo 安装计划任务（每 6 小时）...
schtasks /create /f /tn "YanlerApkSync" /tr "\"%PYTHON%\" \"%SCRIPT%\"" /sc hourly /mo 6

echo 安装登录时同步（启动文件夹）...
copy /y "%~dp0yanler_apk_sync.cmd" "%STARTUP%\" >nul

echo.
echo 立即执行一次验证...
"%PYTHON%" "%SCRIPT%"

echo.
echo 完成。查看同步日志：D:\apk\sync.log
pause
