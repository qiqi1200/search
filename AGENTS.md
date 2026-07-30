# Yanler 浏览器 — Agent 操作指南

## 项目位置
```
D:\search\yanler_browser\     ← Flutter 项目根目录（也是 Git 仓库）
```

## 关键命令
```bash
# 进入项目
cd /d/search/yanler_browser

# 静态分析（提交前必跑，确保 0 error）
flutter analyze

# 检查是否存在 error/warning
flutter analyze 2>&1 | grep -cE "^(  error|  warning)" && echo "通过" || echo "有问题"

# 安装依赖
flutter pub get

# 运行（需要设备）
flutter run                    # Android
flutter run -d windows         # Windows

# 打包
flutter build apk --release            # Android APK
flutter build appbundle --release       # Android AAB（商店用）
flutter build windows --release         # Windows exe

# Git 推送
git add -A
git commit -m "描述改动"
git push
```

## 项目结构（核心）
```
lib/
├── main.dart                         # 入口
├── core/
│   ├── theme/app_theme.dart          # 主题（浅色/深色）
│   └── constants/search_engines.dart # 搜索引擎列表
├── features/
│   ├── browser/                      # 浏览器核心
│   │   ├── screens/browser_screen.dart
│   │   └── widgets/
│   │       ├── new_tab_page.dart     # 新标签页（Yanler Logo + 诗词）
│   │       ├── address_bar.dart      # 地址栏
│   │       ├── bottom_bar.dart       # 底部多功能按钮
│   │       ├── tab_switcher.dart     # 标签切换器
│   │       └── webview_container.dart # WebView 容器
│   ├── adblock/adblock_engine.dart   # 广告过滤引擎
│   ├── settings/settings_screen.dart # 设置页面
│   └── bookmarks/bookmark_service.dart
├── providers/
│   ├── browser_provider.dart         # 浏览器状态
│   ├── settings_provider.dart        # 设置状态
│   └── ai_provider.dart              # AI 助手
```

## 设计约束
- 广告过滤：必须拦截所有广告，不放行成人内容以外的任何广告
- 隐私：不收集任何用户数据，支持 DNT、第三方 Cookie 拦截、无痕模式
- AI：支持自定义 API Key，代理模式可管理浏览器
- 样式：液态玻璃美学，渐变 Logo，打字机诗词效果
- 底部栏：简洁设计，一个多功能按钮集成菜单

## GitHub
- 远程仓库: `qiqi1200/search`
- 分支: `main`
- GitHub Actions 在 `.github/workflows/` 下
- 打包产物自动上传到 GitHub Releases
