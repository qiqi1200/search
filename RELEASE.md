# 发布流程

## 通过 GitHub Actions 自动构建（推荐）

### 手动触发构建
1. 打开 https://github.com/qiqi1200/search/actions
2. 选择 **Build & Analyze** workflow
3. 点 **Run workflow** → 选 `main` 分支 → 点绿色按钮
4. 等待 ~10 分钟，构建完成后在 Action 页面下载 APK

### 发布新版本
1. 打开 https://github.com/qiqi1200/search/releases
2. 点 **Create a new release**
3. 填写版本号（如 `v1.0.1`）和说明
4. 发布后自动触发 **Release APK & Windows** workflow
5. 构建完成后 APK/zip 自动上传到 Release 附件

---

## 本地构建

```bash
# Android APK
cd /d/search/yanler_browser
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk

# Windows 桌面版
flutter build windows --release
# 产物: build/windows/runner/Release/

# 安装包（需要额外工具）
# Windows 用 MSIX: flutter build windows --release
# 然后用 msix打包工具创建安装程序
```

## 分发渠道
| 平台 | 方式 | 备注 |
|------|------|------|
| Android | GitHub Releases | 直接下载 APK 安装 |
| Windows | GitHub Releases | 下载 zip 解压运行 |
| 官网 | GitHub Pages (可选) | 放介绍 + 下载链接 |
