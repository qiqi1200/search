import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ai_provider.dart';
import '../../core/constants/search_engines.dart';
import '../../core/widgets/liquid_glass.dart';
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
      ],
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
      builder: (_) => const _AIConfigSheet(),
    );
  }
}

class _AIConfigSheet extends StatefulWidget {
  const _AIConfigSheet();

  @override
  State<_AIConfigSheet> createState() => _AIConfigSheetState();
}

class _AIConfigSheetState extends State<_AIConfigSheet> {
  final _keyController = TextEditingController();
  final _urlController = TextEditingController(
    text: 'https://api.openai.com/v1/chat/completions',
  );
  final _modelController = TextEditingController(text: 'gpt-3.5-turbo');

  @override
  void initState() {
    super.initState();
    final ai = context.read<AIProvider>();
    // Don't prefill API key for security
    _urlController.text = ai.apiUrl;
    _modelController.text = ai.model;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.center,
          ),
          const SizedBox(height: 24),
          Text('配置 AI API', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-3.5-turbo, deepseek-chat, etc.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_keyController.text.trim().isEmpty) return;
                context.read<AIProvider>().configure(
                  apiKey: _keyController.text.trim(),
                  apiUrl: _urlController.text.trim(),
                  model: _modelController.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API 配置已保存')),
                );
              },
              child: const Text('保存配置'),
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
      opacity: isDark ? 0.5 : 0.6,
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
