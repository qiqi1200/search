# Yanler 浏览器

> 纯净无广告 · 丝滑 UI · AI 智能 · 隐私优先

Yanler（发音 /jænˈlɜːr/）是一款极简无广告的浏览器应用，支持 Android 和 Windows 双平台。

---

## ✨ 特性

### 🚫 广告过滤
基于 EasyList 规则引擎，拦截网页中所有广告、追踪器和弹窗。
- 内置 200+ 广告网络规则（Google、百度、腾讯、字节跳动等）
- 支持自动从 CDN 更新过滤规则
- 不影响成人内容访问

### 🔒 隐私保护
- Do Not Track (DNT) 请求头
- 第三方 Cookie 拦截
- 无痕浏览模式
- 无用户追踪，不收集任何数据

### 🤖 AI 助手
- 内置 AI 聊天助手
- **代理模式**：AI 可管理浏览器设置、书签、历史
- 支持自定义 API Key 和模型（OpenAI、DeepSeek、Claude 等）

### 🎨 UI 设计
- 液态玻璃美学（毛玻璃 + 渐变）
- 浅色/深色双模式
- 120fps 丝滑动效
- 极简底部多功能按钮

### 📜 诗意新标签页
- Yanler 艺术字体渐变 Logo
- 每 6 秒自动切换随机中国古诗词
- 打字机逐字输出效果

---

## 🏗️ 项目结构

```
yanler_browser/
├── lib/
│   ├── main.dart                          # 入口
│   ├── core/
│   │   ├── theme/app_theme.dart           # 主题系统
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # 应用常量
│   │   │   └── search_engines.dart        # 搜索引擎列表
│   │   └── utils/poem_database.dart       # 诗词数据库
│   ├── features/
│   │   ├── browser/
│   │   │   ├── screens/browser_screen.dart     # 主浏览器页
│   │   │   └── widgets/
│   │   │       ├── address_bar.dart            # 地址栏
│   │   │       ├── bottom_bar.dart             # 底部操作栏
│   │   │       ├── new_tab_page.dart           # 新标签页
│   │   │       ├── tab_switcher.dart           # 标签切换器
│   │   │       └── webview_container.dart      # WebView 容器
│   │   ├── adblock/adblock_engine.dart    # 广告过滤引擎
│   │   ├── ai/                            # AI 模块
│   │   │   ├── ai_service.dart            # AI 通信服务
│   │   │   └── ai_agent.dart              # AI 代理逻辑
│   │   ├── bookmarks/bookmark_service.dart # 书签服务
│   │   ├── history/history_service.dart    # 历史记录服务
│   │   ├── search/search_service.dart     # 搜索服务
│   │   └── settings/settings_screen.dart  # 设置页面
│   └── providers/
│       ├── browser_provider.dart          # 浏览器状态
│       ├── settings_provider.dart         # 设置状态
│       └── ai_provider.dart               # AI 状态
├── assets/
│   ├── poems/                             # 诗词数据（可选扩展）
│   └── fonts/                             # 自定义字体
├── android/                               # Android 原生
├── windows/                               # Windows 原生
└── pubspec.yaml
```

---

## 🚀 开发

### 前置条件
- Flutter SDK 3.24+
- Android Studio / VS Code

### 运行

```bash
cd yanler_browser

# 安装依赖
flutter pub get

# 运行（Android）
flutter run

# 运行（Windows）
flutter run -d windows
```

### 打包

```bash
# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

---

## 📦 下载

编译好的安装包发布在 GitHub Releases。支持：
- Android APK
- Windows MSIX 安装包

---

## 🔧 配置

### AI 助手配置
1. 打开设置 → AI 助手
2. 输入 API Key（支持 OpenAI、DeepSeek、Anthropic 等）
3. 可选：自定义 API 地址和模型名称
4. 开启代理模式让 AI 管理浏览器

---

## 🛡️ 隐私政策

Yanler **不收集任何用户数据**：
- 无分析追踪
- 无广告 SDK
- 所有数据存储在本地
- AI 请求直接发送到用户配置的 API

---

## 📄 开源协议

MIT License © 2025 qiqi1200
