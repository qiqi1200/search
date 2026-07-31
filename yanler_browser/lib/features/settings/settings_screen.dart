import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ai_provider.dart';
import '../../core/constants/search_engines.dart';
import '../../core/constants/wallpapers.dart';
import '../../core/widgets/liquid_glass.dart';
import '../ai/ai_config_sheet.dart';
import '../bookmarks/bookmark_service.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../history/history_service.dart';
import '../history/history_screen.dart';

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
          _AISection(),
          SizedBox(height: 16),
          _DataSection(),
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
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择搜索引擎',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...SearchEngines.engines.map(
              (engine) => ListTile(
                leading: Image.network(
                  engine.iconUrl,
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.search),
                ),
                title: Text(engine.name),
                trailing: settings.searchEngine == engine.name
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  settings.setSearchEngine(engine.name);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
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
          value: _wallpaperName(settings.wallpaperId),
          onTap: () => _showWallpaperPicker(context, settings),
        ),
      ],
    );
  }

  String _wallpaperName(String id) {
    if (id == Wallpapers.defaultId) return '默认';
    return Wallpapers.byId(id).name;
  }

  void _showWallpaperPicker(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LiquidGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 24,
        opacity: isDark ? 0.8 : 0.75,
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
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      blur: 18,
      opacity: isDark ? 0.45 : 0.5,
      borderWidth: 1,
      shadows: GlassTokens.softShadow(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
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
    MaterialPageRoute(builder: (_) => screen),
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
  final VoidCallback onTap;

  const _WallpaperSwatch({
    required this.label,
    required this.selected,
    required this.gradient,
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
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.9),
                  )
                : null,
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
