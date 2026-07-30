import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../../providers/browser_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/search_engines.dart';
import '../../../providers/ai_provider.dart';
import '../../settings/settings_screen.dart';
import '../../adblock/adblock_engine.dart';
import '../widgets/address_bar.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/tab_switcher.dart';
import '../widgets/new_tab_page.dart';
import '../widgets/webview_container.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browser = context.read<BrowserProvider>();
      if (browser.tabCount == 0) {
        browser.addTab();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUrlSubmitted(String url) {
    final browser = context.read<BrowserProvider>();
    final settings = context.read<SettingsProvider>();

    String finalUrl = url.trim();
    // 检测是否为搜索词
    if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://') &&
        !finalUrl.contains('.')) {
      final engine = SearchEngines.byName(settings.searchEngine);
      finalUrl = '${engine.url}${Uri.encodeComponent(finalUrl)}';
    } else if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (browser.activeTabIndex >= 0) {
      browser.updateTabUrl(browser.activeTabIndex, finalUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrowserProvider, SettingsProvider>(
      builder: (context, browser, settings, _) {
        final isOnNewTab = browser.activeTab?.url.isEmpty ?? true;
        final adblock = context.watch<AdblockEngine>();

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 地址栏
                if (!isOnNewTab)
                  AddressBar(
                    url: browser.activeTab?.url ?? '',
                    isLoading: browser.activeTab?.isLoading ?? false,
                    onSubmitted: _onUrlSubmitted,
                  ),

                // 页面内容
                Expanded(
                  child: isOnNewTab
                      ? const NewTabPage()
                      : WebViewContainer(
                          key: ValueKey(browser.activeTab?.id),
                          tabId: browser.activeTab?.id ?? '',
                          initialUrl: browser.activeTab?.url ?? '',
                          onUrlChanged: (url) {
                            final activeIndex = browser.activeTabIndex;
                            if (activeIndex >= 0) {
                              browser.updateTabUrl(activeIndex, url);
                            }
                          },
                          onTitleChanged: (title) {
                            final activeIndex = browser.activeTabIndex;
                            if (activeIndex >= 0) {
                              browser.updateTabTitle(activeIndex, title);
                            }
                          },
                          onLoadingChanged: (loading) {
                            final activeIndex = browser.activeTabIndex;
                            if (activeIndex >= 0) {
                              browser.setTabLoading(activeIndex, loading);
                            }
                          },
                          onControllerReady: (controller) {
                            _webViewController = controller;
                          },
                          onNavigationStateChanged: (canBack, canFwd) {
                            if (mounted) {
                              setState(() {
                                _canGoBack = canBack;
                                _canGoForward = canFwd;
                              });
                            }
                          },
                        ),
                ),

                // 底部栏
                BottomBar(
                  tabCount: browser.tabCount,
                  isIncognito: browser.isIncognitoMode,
                  canGoBack: _canGoBack,
                  canGoForward: _canGoForward,
                  adBlockCount: adblock.blockedCount,
                  onBack: () => _webViewController?.goBack(),
                  onForward: () => _webViewController?.goForward(),
                  onHome: () => _goHome(browser),
                  onAI: () => _toggleAI(context),
                  onTabSwitch: () => _showTabSwitcher(context),
                  onMenu: () => _showMenu(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTabSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TabSwitcherSheet(),
    );
  }

  void _goHome(BrowserProvider browser) {
    // 回到新标签页
    final activeIndex = browser.activeTabIndex;
    if (activeIndex >= 0) {
      browser.updateTabUrl(activeIndex, '');
    }
    setState(() {
      _canGoBack = false;
      _canGoForward = false;
      _webViewController = null;
    });
  }

  void _showMenu(BuildContext context) {
    final adblock = context.read<AdblockEngine>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomMenuSheet(
        adBlockCount: adblock.blockedCount,
        onToggleTheme: () {
          context.read<SettingsProvider>().toggleTheme();
          Navigator.pop(context);
        },
        onOpenSettings: () {
          Navigator.pop(context);
          _openSettings(context);
        },
        onToggleIncognito: () {
          context.read<BrowserProvider>().toggleIncognito();
          Navigator.pop(context);
        },
        onToggleAI: () {
          Navigator.pop(context);
          _toggleAI(context);
        },
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _toggleAI(BuildContext context) {
    final aiProvider = context.read<AIProvider>();
    if (aiProvider.isConfigured) {
      aiProvider.toggleAgentMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aiProvider.agentMode ? 'AI 代理模式已开启' : 'AI 代理模式已关闭',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ),
      );
    }
  }
}

// 底部菜单面板（三点菜单）
class _BottomMenuSheet extends StatelessWidget {
  final int adBlockCount;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleIncognito;
  final VoidCallback onToggleAI;

  const _BottomMenuSheet({
    required this.adBlockCount,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.onToggleIncognito,
    required this.onToggleAI,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // 广告拦截统计条
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '广告拦截',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '已拦截 $adBlockCount 个',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MenuButton(
                icon: isDark ? Icons.light_mode : Icons.dark_mode,
                label: isDark ? '浅色' : '深色',
                onTap: onToggleTheme,
              ),
              _MenuButton(
                icon: Icons.settings,
                label: '设置',
                onTap: onOpenSettings,
              ),
              _MenuButton(
                icon: Icons.privacy_tip_outlined,
                label: '无痕',
                onTap: onToggleIncognito,
              ),
              _MenuButton(
                icon: Icons.auto_awesome,
                label: 'AI',
                onTap: onToggleAI,
              ),
              _MenuButton(
                icon: Icons.bookmark_border,
                label: '书签',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show bookmarks
                },
              ),
              _MenuButton(
                icon: Icons.history,
                label: '历史',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show history
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(icon, size: 24, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
