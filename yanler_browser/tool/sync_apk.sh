#!/usr/bin/env bash
# Yanler APK 同步 — Hermes 定时任务包装（用固定 Python 3.11 解释器，避免系统 PATH 里的旧版本）
"/c/Users/lenovo/AppData/Local/hermes/hermes-agent/venv/Scripts/python.exe" \
  "D:\\search\\yanler_browser\\tool\\sync_apk.py" --quiet
