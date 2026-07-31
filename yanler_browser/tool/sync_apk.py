#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Yanler APK 自动同步器

检测 GitHub Releases 的最新版本，有新版本时下载 APK 并替换 D:\\apk 下的旧包。
配合 Windows 计划任务（tool/setup_apk_sync.bat 安装）自动运行：
  - 登录时跑一次
  - 每 6 小时跑一次

幂等：已同步过的版本（记录在 D:\\apk\\.synced_version）会静默跳过；
GitHub 不可达时（如校园网）静默失败，下次运行自动恢复。
"""
import datetime
import json
import os
import shutil
import sys
import urllib.request

APK_DIR = r"D:\apk"
REPO = "qiqi1200/search"
API_URL = f"https://api.github.com/repos/{REPO}/releases/latest"
STATE_FILE = os.path.join(APK_DIR, ".synced_version")
LOG_FILE = os.path.join(APK_DIR, "sync.log")
UA = {"User-Agent": "Yanler-Apk-Sync/1.0"}


def log(msg: str) -> None:
    line = f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def fetch_json(url: str, timeout: int = 20) -> dict:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def download(url: str, dest: str) -> None:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=600) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)


def main() -> int:
    os.makedirs(APK_DIR, exist_ok=True)

    # 1. 查最新 Release
    try:
        data = fetch_json(API_URL)
    except Exception as e:
        log(f"检查更新失败（网络不可用？）：{e}")
        return 0  # 静默失败，下次再试

    tag = (data.get("tag_name") or "").lstrip("v")
    assets = data.get("assets") or []
    url = next(
        (
            a.get("browser_download_url")
            for a in assets
            if (a.get("name") or "").lower().endswith(".apk")
        ),
        None,
    )
    if not tag or not url:
        log("最新 Release 中没有 APK，跳过")
        return 0

    # 2. 已同步则跳过
    synced = ""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, encoding="utf-8") as f:
            synced = f.read().strip()
    if synced == tag:
        return 0  # 无新版本，完全静默

    # 3. 下载到临时文件，再原子替换
    dest = os.path.join(APK_DIR, f"yanler-{tag}-release.apk")
    tmp = dest + ".tmp"
    try:
        log(f"发现新版本 v{tag}，开始下载…")
        download(url, tmp)
    except Exception as e:
        log(f"下载失败：{e}")
        try:
            os.remove(tmp)
        except Exception:
            pass
        return 1

    # 4. 清理旧包（保留本次目标文件）
    for name in os.listdir(APK_DIR):
        if name.startswith("yanler-") and name.endswith(".apk") and name != os.path.basename(dest):
            try:
                os.remove(os.path.join(APK_DIR, name))
                log(f"已删除旧包 {name}")
            except Exception:
                pass

    os.replace(tmp, dest)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        f.write(tag)
    log(f"✓ 已同步 v{tag} -> {dest}（{os.path.getsize(dest) / 1024 / 1024:.1f} MB）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
