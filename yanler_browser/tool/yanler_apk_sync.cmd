@echo off
REM Yanler APK 自动同步（登录时静默运行，由 setup_apk_sync.bat 复制到启动文件夹）
start /b "" "C:\Users\lenovo\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe" "D:\search\yanler_browser\tool\sync_apk.py"
