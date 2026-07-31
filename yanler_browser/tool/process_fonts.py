#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Yanler 字体管线（重新生成时运行：python tool/process_fonts.py）

1. 思源宋体 (SourceHanSerifCN-Regular.otf) 子集化
   -> 仅保留 lib/core/utils/poem_database.dart 用到的字符，~144KB
2. Outfit 可变字体 -> 实例化静态字重 200/300/400/500/600/700

源文件下载（GitHub 被墙时用 jsdelivr CDN）：
- 宋体: https://cdn.jsdelivr.net/gh/adobe-fonts/source-han-serif@release/SubsetOTF/CN/SourceHanSerifCN-Regular.otf
- Outfit: https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/outfit/Outfit%5Bwght%5D.ttf
"""
import os, re, subprocess, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")
SRC_SERIF = os.path.join(OUT_DIR, "_src_SourceHanSerifCN-Regular.otf")
SRC_OUTFIT = os.path.join(OUT_DIR, "_src_Outfit-var.ttf")

SERIF_URL = ("https://cdn.jsdelivr.net/gh/adobe-fonts/source-han-serif@release/"
             "SubsetOTF/CN/SourceHanSerifCN-Regular.otf")
OUTFIT_URL = ("https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/outfit/"
              "Outfit%5Bwght%5D.ttf")


def fetch(url: str, dest: str) -> None:
    if os.path.exists(dest) and os.path.getsize(dest) > 100_000:
        print(f"skip download: {os.path.basename(dest)} exists")
        return
    print(f"downloading {os.path.basename(dest)} ...")
    urllib.request.urlretrieve(url, dest)
    print(f"  -> {os.path.getsize(dest)/1024/1024:.1f} MB")


# 1) 收集诗词字符
poem_src = os.path.join(ROOT, "lib", "core", "utils", "poem_database.dart")
with open(poem_src, encoding="utf-8") as f:
    src = f.read()

pairs = re.findall(r"content:\s*'([^']*)'", src)
authors = re.findall(r"author:\s*'([^']*)'", src)
titles = re.findall(r"title:\s*'([^']*)'", src)

chars = set("".join(pairs + authors + titles))
chars |= set("，。？！；：、——…《》【】“”‘’·（）年月日一二三四五六七八九十")

# 2) 子集化宋体
fetch(SERIF_URL, SRC_SERIF)
chars_txt = os.path.join(OUT_DIR, "_subset_chars.txt")
with open(chars_txt, "w", encoding="utf-8") as f:
    f.write("".join(sorted(chars)))

out_serif = os.path.join(OUT_DIR, "SourceHanSerifSC-Regular.otf")
subprocess.run([
    sys.executable, "-m", "fontTools.subset", SRC_SERIF,
    f"--text-file={chars_txt}",
    f"--output-file={out_serif}",
    "--no-hinting",
    "--layout-features=*",
    "--drop-tables+=GSUB,GPOS",
], check=True)
print(f"serif subset: {os.path.getsize(out_serif)/1024:.1f} KB  chars={len(chars)}")

# 3) Outfit 可变字体实例化
fetch(OUTFIT_URL, SRC_OUTFIT)
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

weights = {200: "ExtraLight", 300: "Light", 400: "Regular",
           500: "Medium", 600: "SemiBold", 700: "Bold"}
for w, name in weights.items():
    out = os.path.join(OUT_DIR, f"Outfit-{name}.ttf")
    font = TTFont(SRC_OUTFIT)
    instantiateVariableFont(font, {"wght": w}, inplace=True)
    font.save(out)
    print(f"Outfit-{name}: {os.path.getsize(out)/1024:.1f} KB")

os.remove(chars_txt)
os.remove(SRC_SERIF)
os.remove(SRC_OUTFIT)
print("DONE")
