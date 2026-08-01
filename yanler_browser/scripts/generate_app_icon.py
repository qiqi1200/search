#!/usr/bin/env python3
"""
生成 Yanler 浏览器启动图标

Android 自适应图标规范：
- 前景图 (foreground): 元素应在中心 66% 区域内（即留出 17% 内边距）
- 背景图 (background): 纯色或渐变
- 完整图标: 1024x1024 像素

运行: python scripts/generate_app_icon.py
"""

from PIL import Image, ImageDraw, ImageFont
import os

# 配置
SIZE = 1024
SAFE_ZONE = 0.66  # 中心安全区域
ICON_DIR = "assets/icon"

def create_gradient_background(size, color1, color2):
    """创建渐变背景"""
    img = Image.new('RGB', (size, size), color1)
    draw = ImageDraw.Draw(img)
    
    for y in range(size):
        ratio = y / size
        r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
        g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
        b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    return img

def draw_rounded_rect(draw, xy, radius, fill):
    """绘制圆角矩形"""
    x1, y1, x2, y2 = xy
    r = radius
    
    # 主体
    draw.rectangle([x1 + r, y1, x2 - r, y2], fill=fill)
    draw.rectangle([x1, y1 + r, x2, y2 - r], fill=fill)
    
    # 四个圆角
    draw.ellipse([x1, y1, x1 + r * 2, y1 + r * 2], fill=fill)
    draw.ellipse([x2 - r * 2, y1, x2, y1 + r * 2], fill=fill)
    draw.ellipse([x1, y2 - r * 2, x1 + r * 2, y2], fill=fill)
    draw.ellipse([x2 - r * 2, y2 - r * 2, x2, y2], fill=fill)

def generate_icons():
    os.makedirs(ICON_DIR, exist_ok=True)
    
    # 颜色配置
    primary_color = (107, 140, 255)  # #6B8CFF
    secondary_color = (155, 107, 255)  # #9B6BFF
    bg_light = (245, 245, 245)  # #F5F5F5
    
    # ===== 1. 创建完整图标 (icon.png) =====
    full_icon = Image.new('RGB', (SIZE, SIZE), bg_light)
    draw = ImageDraw.Draw(full_icon)
    
    # 图标主体：圆角矩形底座 + Y 字母
    margin = SIZE // 8
    rect_size = SIZE - 2 * margin
    corner_radius = rect_size // 6
    
    # 渐变背景矩形
    rect_img = create_gradient_background(rect_size, primary_color, secondary_color)
    
    # 绘制圆角遮罩
    mask = Image.new('L', (rect_size, rect_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    draw_rounded_rect(mask_draw, (0, 0, rect_size, rect_size), corner_radius, 255)
    
    # 应用遮罩
    rect_img.putalpha(mask)
    full_icon.paste(rect_img, (margin, margin), rect_img)
    
    # 添加 Y 字母
    try:
        # 尝试使用系统字体
        font_size = rect_size // 2
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
    except:
        font = ImageFont.load_default()
    
    draw = ImageDraw.Draw(full_icon)
    text = "Y"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = (SIZE - text_width) // 2
    text_y = (SIZE - text_height) // 2 - text_height // 4
    draw.text((text_x, text_y), text, fill="white", font=font)
    
    full_icon.save(os.path.join(ICON_DIR, "icon.png"))
    print(f"✅ 已生成: {ICON_DIR}/icon.png ({SIZE}x{SIZE})")
    
    # ===== 2. 创建前景图 (icon_foreground.png) =====
    # 关键：元素必须在中心 66% 区域内
    fg_size = SIZE
    fg_img = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
    fg_draw = ImageDraw.Draw(fg_img)
    
    # 计算安全区域
    safe_margin = int(fg_size * (1 - SAFE_ZONE) / 2)
    safe_size = fg_size - 2 * safe_margin
    
    # 在安全区域内绘制图标
    fg_corner_radius = safe_size // 6
    
    # 渐变矩形
    fg_rect = create_gradient_background(safe_size, primary_color, secondary_color)
    fg_mask = Image.new('L', (safe_size, safe_size), 0)
    fg_mask_draw = ImageDraw.Draw(fg_mask)
    draw_rounded_rect(fg_mask_draw, (0, 0, safe_size, safe_size), fg_corner_radius, 255)
    fg_rect.putalpha(fg_mask)
    fg_img.paste(fg_rect, (safe_margin, safe_margin), fg_rect)
    
    # 添加 Y 字母
    try:
        fg_font_size = safe_size // 2
        fg_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", fg_font_size)
    except:
        fg_font = ImageFont.load_default()
    
    fg_draw = ImageDraw.Draw(fg_img)
    bbox = fg_draw.textbbox((0, 0), text, font=fg_font)
    fg_text_width = bbox[2] - bbox[0]
    fg_text_height = bbox[3] - bbox[1]
    fg_text_x = (fg_size - fg_text_width) // 2
    fg_text_y = (fg_size - fg_text_height) // 2 - fg_text_height // 4
    fg_draw.text((fg_text_x, fg_text_y), text, fill="white", font=fg_font)
    
    fg_img.save(os.path.join(ICON_DIR, "icon_foreground.png"))
    print(f"✅ 已生成: {ICON_DIR}/icon_foreground.png ({fg_size}x{fg_size}, 安全区域 {int(SAFE_ZONE*100)}%)")
    
    print("\n使用说明:")
    print("1. 安装依赖: flutter pub add --dev flutter_launcher_icons")
    print("2. 生成图标: flutter pub run flutter_launcher_icons")
    print("3. 重新打包 APK 查看效果")

if __name__ == "__main__":
    generate_icons()
