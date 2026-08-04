import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ai_provider.dart';
import '../../providers/quick_links_provider.dart';
import '../../core/constants/search_engines.dart';
import '../../core/theme/snappy_route.dart';
import '../../core/constants/wallpapers.dart';
import '../../core/widgets/yanler_surface.dart';
import '../ai/ai_config_sheet.dart';
import '../bookmarks/bookmark_service.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../history/history_service.dart';
import '../history/history_screen.dart';
import '../updater/update_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          _SearchSection(),
          SizedBox(height: 16),
          _PrivacySection(),
          SizedBox(height: 16),
          _AppearanceSection(),
          SizedBox(height: 16),
          _QuickLinksSection(),
          SizedBox(height: 16),
          _AISection(),
          SizedBox(height: 16),
          _DataSection(),
          SizedBox(height: 16),
          _AboutSection(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return _SettingsCard(
      title: '搜索',
      icon: Icons.search,
      children: [
        _SettingsRow(
          label: '默认搜索引擎',
          value: settings.searchEngine,
          onTap: () => _showEnginePicker(context, settings),
        ),
        const _Divider(),
        _SettingsRow(
          label: '首页',
          value: settings.homepage.isEmpty ? '新标签页' : settings.homepage,
          onTap: () => _showHomepageDialog(context, settings),
        ),
      ],
    );
  }

  void _showHomepageDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.homepage);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设置首页'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '首页地址',
            hintText: '留空 = 新标签页',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              settings.setHomepage(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showEnginePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // 实色底部弹层
      builder: (sheetContext) => YanlerSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        elevated: false,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 14,
              bottom: 12,
              left: 8,
              right: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('选择搜索引擎',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Flexible + ListView(shrinkWrap)：引擎较多时弹层内可滚动，
                // 避免超出底部被系统手势条/屏幕边缘遮挡
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: SearchEngines.engines
                        .map(
                          (engine) => ListTile(
                            leading: Image.network(
                              engine.iconUrl,
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.search),
                            ),
                            title: Text(engine.name),
                            trailing: settings.searchEngine == engine.name
                                ? Icon(Icons.check,
                                    color: Theme.of(context).colorScheme.primary)
                                : null,
                            onTap: () {
                              settings.setSearchEngine(engine.name);
                              Navigator.pop(sheetContext);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return _SettingsCard(
      title: '隐私与安全',
      icon: Icons.privacy_tip_outlined,
      children: [
        _SwitchRow(
          label: '广告过滤',
          subtitle: '拦截广告和追踪器',
          value: settings.adblockEnabled,
          onChanged: (v) => settings.setAdblockEnabled(v),
        ),
        const _Divider(),
        _SwitchRow(
          label: '禁止追踪 (DNT)',
          subtitle: '向网站发送不追踪请求',
          value: settings.doNotTrack,
          onChanged: (v) {},
        ),
        const _Divider(),
        _SwitchRow(
          label: '拦截第三方 Cookie',
          subtitle: '防止跨站追踪',
          value: settings.blockThirdPartyCookies,
          onChanged: (v) {},
        ),
        const _Divider(),
        _SwitchRow(
          label: '洁净浏览模式',
          subtitle: '阅读页自动去除广告/弹窗/浮层',
          value: settings.readingModeEnabled,
          onChanged: (v) => settings.setReadingModeEnabled(v),
        ),
        const _Divider(),
        _SwitchRow(
          label: '弹窗广告屏蔽',
          subtitle: '拦截 window.open 自动弹窗，恶意弹窗直接关闭',
          value: settings.popupBlockEnabled,
          onChanged: (v) => settings.setPopupBlockEnabled(v),
        ),
        const _Divider(),
        _SwitchRow(
          label: '漫画无缝续读',
          subtitle: '滚动到底部自动跳转下一章',
          value: settings.comicAutoNext,
          onChanged: (v) => settings.setComicAutoNext(v),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return _SettingsCard(
      title: '外观',
      icon: Icons.palette_outlined,
      children: [
        _SettingsRow(
          label: '主题',
          value: settings.isDarkMode ? '深色' : '浅色',
          onTap: () => settings.toggleTheme(),
        ),
        const _Divider(),
        _SettingsRow(
          label: '壁纸',
          value: _wallpaperName(settings),
          onTap: () => _showWallpaperPicker(context, settings),
        ),
        const _Divider(),
        // 壁纸通透度：遮罩不透明度越小 → 背景壁纸越清晰
        _SliderRow(
          label: '背景通透度',
          hint: '壁纸遮罩不透明度',
          value: settings.wallpaperOpacity,
          min: 0.0,
          max: 0.85,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => settings.setWallpaperOpacity(v),
        ),
        const _Divider(),
        // 液态玻璃磨砂层透明度：越小玻璃越通透
        _SliderRow(
          label: '玻璃通透度',
          hint: '磨砂层透明度',
          value: settings.glassOpacity,
          min: 0.0,
          max: 1.0,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => settings.setGlassOpacity(v),
        ),
      ],
    );
  }

  String _wallpaperName(SettingsProvider settings) {
    if (settings.hasCustomWallpaper) return '自定义';
    if (settings.wallpaperId == Wallpapers.defaultId) return '默认';
    return Wallpapers.byId(settings.wallpaperId).name;
  }

  void _showWallpaperPicker(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // 实色底部弹层
      builder: (sheetContext) => YanlerSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        elevated: false,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('选择壁纸', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    // 默认
                    _WallpaperSwatch(
                      label: '默认',
                      selected: settings.wallpaperId == Wallpapers.defaultId,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF191A1E), const Color(0xFF1D1E24)]
                            : [const Color(0xFFF7F5F2), const Color(0xFFF0EDE9)],
                      ),
                      onTap: () {
                        settings.setWallpaper(Wallpapers.defaultId);
                        Navigator.pop(sheetContext);
                      },
                    ),
                    // 自定义（从本地相册/存储选择）
                    _WallpaperSwatch(
                      label: '自定义',
                      selected: settings.hasCustomWallpaper,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF23252B), const Color(0xFF2C2E36)]
                            : [const Color(0xFFE9E5E0), const Color(0xFFDCD8D2)],
                      ),
                      child: settings.hasCustomWallpaper &&
                              File(settings.customWallpaperPath).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(settings.customWallpaperPath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: Colors.white70,
                            ),
                      onTap: () => _pickCustomWallpaper(context, settings),
                    ),
                    ...Wallpapers.presets.map((w) => _WallpaperSwatch(
                          label: w.name,
                          selected: settings.wallpaperId == w.id,
                          gradient: LinearGradient(colors: w.colorsFor(Theme.of(context).brightness)),
                          onTap: () {
                            settings.setWallpaper(w.id);
                            Navigator.pop(sheetContext);
                          },
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 从本地相册/存储选择照片并保存为自定义壁纸
  Future<void> _pickCustomWallpaper(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2600,
      maxHeight: 2600,
      imageQuality: 92,
    );
    if (picked == null || !context.mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}${Platform.pathSeparator}wallpapers');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    final target = File(
      '${folder.path}${Platform.pathSeparator}custom_'
      '${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    try {
      await File(picked.path).copy(target.path);
    } catch (_) {
      // 部分系统返回只读缓存文件，退化为字节拷贝
      final bytes = await picked.readAsBytes();
      await target.writeAsBytes(bytes);
    }
    if (!context.mounted) return;
    await settings.setCustomWallpaper(target.path);
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('自定义壁纸已应用'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _AISection extends StatelessWidget {
  const _AISection();

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIProvider>();

    return _SettingsCard(
      title: 'AI 助手',
      icon: Icons.auto_awesome,
      children: [
        _SettingsRow(
          label: 'API 状态',
          value: aiProvider.isConfigured ? '已配置' : '未配置',
          valueColor: aiProvider.isConfigured ? Colors.green : null,
          onTap: () => _showAISettings(context, aiProvider),
        ),
        const _Divider(),
        _SwitchRow(
          label: '代理模式',
          subtitle: 'AI 可管理浏览器设置与书签',
          value: aiProvider.agentMode,
          onChanged: (_) => aiProvider.toggleAgentMode(),
        ),
        if (aiProvider.isConfigured) ...[
          const _Divider(),
          _SettingsRow(
            label: '当前模型',
            value: aiProvider.model,
            onTap: () {},
          ),
        ],
      ],
    );
  }

  void _showAISettings(BuildContext context, AIProvider aiProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AIConfigSheet(),
    );
  }
}
/// 快捷链接管理 — 首页快捷方式的管理入口（首页已移除「+ 添加」磁贴）
class _QuickLinksSection extends StatelessWidget {
  const _QuickLinksSection();

  @override
  Widget build(BuildContext context) {
    final quickLinks = context.watch<QuickLinksProvider>();

    return _SettingsCard(
      title: '快捷链接',
      icon: Icons.grid_view_rounded,
      trailing: TextButton.icon(
        icon: const Icon(Icons.add_rounded, size: 17),
        label: const Text('添加'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: () => _showAddDialog(context, quickLinks),
      ),
      children: quickLinks.links.isEmpty
          ? [
              Text(
                '暂无快捷链接，点右上角「添加」创建首页快捷方式。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ]
          : quickLinks.links
              .map(
                (link) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surfaceContainerLow
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        link.title.characters.first.toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    link.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    link.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 17),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onPressed: () => quickLinks.remove(link.id),
                  ),
                ),
              )
              .toList(),
    );
  }

  void _showAddDialog(BuildContext context, QuickLinksProvider quickLinks) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加快捷链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：知乎',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '网址',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              final normalized = url.contains('.') ? url : 'https://$url';
              quickLinks.add(titleController.text, normalized);
              Navigator.pop(dialogContext);
            },
            child: Text(
              '添加',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarkService>();
    final history = context.watch<HistoryService>();

    return _SettingsCard(
      title: '数据管理',
      icon: Icons.storage_outlined,
      children: [
        _SettingsRow(
          label: '书签',
          value: '${bookmarks.count} 个',
          onTap: () => _openListScreen(context, const BookmarksScreen()),
        ),
        const _Divider(),
        _SettingsRow(
          label: '历史记录',
          value: '${history.count} 条',
          onTap: () => _openListScreen(context, const HistoryScreen()),
        ),
        const _Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('清除所有数据', style: TextStyle(color: Colors.red)),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('确认清除'),
                content: const Text('这将删除所有浏览数据，包括历史记录、书签和缓存。此操作不可撤销。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<BookmarkService>().clear();
                      context.read<HistoryService>().clear();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('数据已清除')),
                      );
                    },
                    child: const Text('确认清除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============ 辅助组件 ============

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.icon,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 实色设置分组卡片
    return YanlerSurface(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 打开书签/历史页，选中条目后回传 URL 并关闭设置页
void _openListScreen(BuildContext context, Widget screen) {
  Navigator.push(
    context,
    SnappyRoute(builder: (_) => screen),
  ).then((url) {
    if (url is String && url.isNotEmpty && context.mounted) {
      Navigator.pop(context, url);
    }
  });
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          color: valueColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// 滑块设置项（通透度调节等）
class _SliderRow extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14.5),
              ),
            ),
            Text(
              format(value),
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          hint,
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.outlineVariant,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
    );
  }
}

/// 壁纸选择色块
class _WallpaperSwatch extends StatelessWidget {
  final String label;
  final bool selected;
  final Gradient gradient;
  final Widget? child;
  final VoidCallback onTap;

  const _WallpaperSwatch({
    required this.label,
    required this.selected,
    required this.gradient,
    this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.5),
                width: selected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child ??
                (selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.9),
                      )
                    : null),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 关于 — 版本号与检查更新
class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = p.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: '关于',
      icon: Icons.info_outline_rounded,
      children: [
        _SettingsRow(
          label: '版本',
          value: 'v$_version',
          onTap: () {},
        ),
        const _Divider(),
        _SettingsRow(
          label: '检查更新',
          value: 'GitHub Releases',
          onTap: () => UpdateService.runCheckWithUi(context),
        ),
        const _Divider(),
        _SettingsRow(
          label: '更新日志',
          value: '查看',
          onTap: () => launchUrl(
            Uri.parse('https://github.com/qiqi1200/search/releases'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}
