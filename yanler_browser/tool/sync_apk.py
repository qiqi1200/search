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
import argparse
import datetime
import json
import os
import re
import shutil
import sys
import time
import urllib.request

APK_DIR = r"D:\apk"
REPO = "qiqi1200/search"
API_URL = f"https://api.github.com/repos/{REPO}/releases/latest"
STATE_FILE = os.path.join(APK_DIR, ".synced_version")
LOG_FILE = os.path.join(APK_DIR, "sync.log")
UA = {"User-Agent": "Yanler-Apk-Sync/1.0"}

# --quiet：失败/无更新时完全不打印（仅成功同步时输出），供定时任务 watchdog 使用
QUIET = "--quiet" in sys.argv

# 计划任务把 stdout 重定向到 GBK 编码文件；成功日志里的 `✓` 会触发
# UnicodeEncodeError 导致 print 崩溃、脚本以非零码退出（任务误判失败）。
# 强制 UTF-8 + errors=replace，保证任何字符都能安全打印。
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError):
    pass  # 非文本流或旧版 Python，忽略


def log(msg: str, notify: bool = True) -> None:
    line = f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    if notify or not QUIET:
        print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


MIRRORS = [
    # 国内加速镜像（多源竞速，直连失败/卡顿时回退）
    "https://ghfast.top/",
    "https://gh-proxy.com/",
    "https://ghproxy.net/",
    "https://ghproxy.cc/",
    "https://mirror.ghproxy.com/",
    "https://gh.llkk.cc/",
]


def fetch_json(url: str, timeout: int = 20) -> dict:
    """直连优先，失败时回退到加速镜像（与 download 一致）。"""
    last_err: Exception = RuntimeError("no api source")
    for src in [url] + [m + url for m in MIRRORS]:
        try:
            req = urllib.request.Request(src, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            last_err = e
    raise last_err


def _download_single(url: str, dest: str, timeout: int = 90) -> None:
    """带停滞检测与完整性校验的下载。"""
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r, open(dest, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        received = 0
        last_activity = time.time()
        while True:
            chunk = r.read(65536)
            if not chunk:
                break
            f.write(chunk)
            received += len(chunk)
            now = time.time()
            if now - last_activity > 120:
                raise TimeoutError("下载停滞（120 秒无数据）")
            last_activity = now
        if total and received != total:
            raise IOError(f"下载不完整：{received}/{total}")


def download(url: str, dest: str) -> None:
    """直连优先，失败/卡顿时自动回退到加速镜像（仅作 fallback）。"""
    sources = [url] + [m + url for m in MIRRORS]
    last_err: Exception = RuntimeError("no download source")
    for i, src in enumerate(sources):
        name = "直连" if i == 0 else "镜像 " + MIRRORS[i - 1]
        try:
            _download_single(src, dest, timeout=300)
            log(f"下载成功（{name}）")
            return
        except Exception as e:
            last_err = e
            log(f"下载失败（{name}）：{e}", notify=False)
            try:
                os.remove(dest)
            except Exception:
                pass
    raise last_err


def prune_old_apks() -> None:
    """D:\apk 只保留版本号最大的 APK，删除其余旧包。

    兼容两种命名：脚本下载的 `yanler-1.4.2-release.apk` 与手动放置的
    `Yanler-1.4.2.apk`。无论来源，都只保留最新版，避免多版本并存。
    """
    try:
        files = [
            f for f in os.listdir(APK_DIR)
            if f.lower().startswith("yanler") and f.endswith(".apk")
        ]
    except OSError:
        return
    if len(files) <= 1:
        return

    def ver(f: str):
        m = re.search(r"(\d+)\.(\d+)\.(\d+)", f)
        return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else (0, 0, 0)

    files.sort(key=ver)
    for old in files[:-1]:
        try:
            os.remove(os.path.join(APK_DIR, old))
            log(f"已清理旧包 {old}")
        except OSError:
            pass


def main() -> int:
    os.makedirs(APK_DIR, exist_ok=True)

    # 0. 清理旧包：只保留版本号最大的一个
    prune_old_apks()

    # 1. 查最新 Release
    try:
        data = fetch_json(API_URL)
    except Exception as e:
        log(f"检查更新失败（网络不可用？）：{e}", notify=False)
        return 0  # 静默失败，下次再试

    tag = (data.get("tag_name") or "").lstrip("v")
    assets = data.get("assets") or []

    def _is_split(name: str) -> bool:
        return any(k in name for k in ("armv7a", "arm64", "x86_64", "windows"))

    # 优先通用包（跳过 armv7a/arm64/x86_64 分发包），避免下载到 split APK
    apks = [a for a in assets if (a.get("name") or "").lower().endswith(".apk")]
    url = None
    for a in apks:
        if not _is_split((a.get("name") or "").lower()):
            url = a.get("browser_download_url")
            break
    if url is None and apks:
        url = apks[0].get("browser_download_url")
    if not tag or not url:
        log("最新 Release 中没有 APK，跳过", notify=False)
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
        log(f"下载失败：{e}", notify=False)
        try:
            os.remove(tmp)
        except Exception:
            pass
        return 1

    os.replace(tmp, dest)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        f.write(tag)
    log(f"✓ 已同步 v{tag} -> {dest}（{os.path.getsize(dest) / 1024 / 1024:.1f} MB）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
